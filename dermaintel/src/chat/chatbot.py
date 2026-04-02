"""
DermaIntel AI Chatbot - RAG-powered conversational interface for dermatologists.

Doctors can have multi-turn conversations about dermatology conditions,
treatments, and drug interactions. The chatbot maintains conversation context
and retrieves evidence from indexed research papers via Tree RAG.
"""

import json
import os
import time
import uuid
from datetime import datetime

import boto3

# Initialize clients
dynamodb = boto3.resource("dynamodb")
CHAT_TABLE = os.environ.get("CHAT_HISTORY_TABLE", "dermaintel-chat-history-dev")
PAPERS_TABLE = os.environ.get("PAPERS_TABLE", "dermaintel-papers-index-dev")
PAPERS_BUCKET = os.environ.get("PAPERS_BUCKET", "dermaintel-papers-dev")
BEDROCK_REGION = os.environ.get("BEDROCK_REGION", "ap-south-1")

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
}

SYSTEM_PROMPT = """You are DermaIntel AI, a clinical decision support chatbot for dermatologists.
You help doctors by answering questions about dermatology conditions, treatments, drug interactions,
and the latest research evidence.

RULES:
1. Grade every clinical claim with evidence level: [A] RCT/meta-analysis, [B] cohort/case-control, [C] case report/expert opinion
2. Cite every claim with [Paper Title, Journal, Year] when evidence is available
3. Flag conflicting findings between papers explicitly
4. Never recommend beyond the evidence - state when evidence is insufficient
5. Include drug interactions if relevant to the query
6. State confidence level: HIGH / MEDIUM / LOW
7. Be conversational but precise - doctors expect clinical accuracy
8. If the user's question is outside dermatology, politely redirect
9. Remember conversation context for follow-up questions
10. ALWAYS end with: "⚕️ Clinical decision support only - not a replacement for physician judgment."

When presenting RAG evidence, format as:
- **Finding**: [description]
- **Evidence**: [Grade] [Citation]
- **Section**: [paper section where found]
"""

MAX_HISTORY_TURNS = 10


def handler(event, context):
    """Lambda handler for POST /chat endpoint."""
    try:
        body = json.loads(event.get("body", "{}"))
        message = body.get("message", "").strip()
        session_id = body.get("session_id", str(uuid.uuid4()))
        user_id = _extract_user_id(event)

        if not message:
            return _response(400, {"error": "Message is required"})

        # 1. Load conversation history
        history = _load_chat_history(user_id, session_id)

        # 2. Classify intent and extract medical entities
        intent = _classify_chat_intent(message, history)

        # 3. Retrieve relevant papers via DynamoDB queries
        papers = _discover_papers(intent)

        # 4. Load tree structures and extract evidence via RAG
        evidence = _retrieve_rag_evidence(papers, message, intent)

        # 5. Generate response with full conversation context
        response_text = _generate_response(message, history, evidence, intent)

        # 6. Save turn to chat history
        _save_chat_turn(user_id, session_id, message, response_text, intent, evidence)

        return _response(200, {
            "session_id": session_id,
            "response": response_text,
            "intent": intent,
            "papers_consulted": len(papers),
            "citations": _format_citations(evidence),
            "confidence": intent.get("confidence", "medium"),
            "timestamp": datetime.utcnow().isoformat(),
        })

    except Exception as e:
        print(f"Chatbot error: {e}")
        return _response(500, {"error": "An error occurred processing your query"})


def _extract_user_id(event):
    """Extract user ID from Cognito JWT claims."""
    try:
        claims = event.get("requestContext", {}).get("authorizer", {}).get("jwt", {}).get("claims", {})
        return claims.get("sub", "anonymous")
    except (KeyError, AttributeError):
        return "anonymous"


def _load_chat_history(user_id, session_id):
    """Load recent conversation history from DynamoDB."""
    try:
        table = dynamodb.Table(CHAT_TABLE)
        response = table.query(
            KeyConditionExpression="PK = :pk AND begins_with(SK, :sk_prefix)",
            ExpressionAttributeValues={
                ":pk": f"USER#{user_id}",
                ":sk_prefix": f"SESSION#{session_id}#",
            },
            ScanIndexForward=True,
            Limit=MAX_HISTORY_TURNS * 2,
        )
        items = response.get("Items", [])
        history = []
        for item in items:
            history.append({
                "role": item.get("role", "user"),
                "content": item.get("content", ""),
            })
        return history[-MAX_HISTORY_TURNS * 2:]
    except Exception as e:
        print(f"Error loading chat history: {e}")
        return []


def _save_chat_turn(user_id, session_id, user_message, assistant_response, intent, evidence):
    """Save conversation turn to DynamoDB."""
    try:
        table = dynamodb.Table(CHAT_TABLE)
        timestamp = datetime.utcnow().isoformat()
        turn_id = str(uuid.uuid4())[:8]

        # Save user message
        table.put_item(Item={
            "PK": f"USER#{user_id}",
            "SK": f"SESSION#{session_id}#TURN#{timestamp}#user",
            "role": "user",
            "content": user_message,
            "session_id": session_id,
            "timestamp": timestamp,
            "intent": json.dumps(intent) if intent else "{}",
        })

        # Save assistant response
        table.put_item(Item={
            "PK": f"USER#{user_id}",
            "SK": f"SESSION#{session_id}#TURN#{timestamp}#assistant",
            "role": "assistant",
            "content": assistant_response,
            "session_id": session_id,
            "timestamp": timestamp,
            "papers_count": len(evidence) if evidence else 0,
        })
    except Exception as e:
        print(f"Error saving chat history: {e}")


def _classify_chat_intent(message, history):
    """Classify the chat message intent using Claude Haiku."""
    bedrock = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)

    context_summary = ""
    if history:
        recent = history[-4:]
        context_summary = "\n".join([f"{m['role']}: {m['content'][:200]}" for m in recent])

    prompt = f"""Classify this dermatology query. Extract structured information.

Conversation context (if any):
{context_summary}

Current message: {message}

Return JSON only:
{{
    "conditions": ["list of skin conditions mentioned or implied"],
    "drugs": ["list of drugs/treatments mentioned"],
    "intent_type": "one of: diagnosis, treatment_protocol, drug_interaction, research_update, differential, follow_up, clarification, general",
    "complexity": "simple or medium or complex",
    "confidence": "high or medium or low",
    "is_follow_up": true/false,
    "search_terms": ["key terms for paper search"]
}}"""

    try:
        response = bedrock.invoke_model(
            modelId="anthropic.claude-3-5-haiku-20241022-v1:0",
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 500,
                "messages": [{"role": "user", "content": prompt}],
            }),
        )
        result = json.loads(response["body"].read())
        text = result["content"][0]["text"]
        # Extract JSON from response
        start = text.find("{")
        end = text.rfind("}") + 1
        if start >= 0 and end > start:
            return json.loads(text[start:end])
    except Exception as e:
        print(f"Intent classification error: {e}")

    return {
        "conditions": [],
        "drugs": [],
        "intent_type": "general",
        "complexity": "simple",
        "confidence": "low",
        "is_follow_up": bool(history),
        "search_terms": message.split()[:5],
    }


def _discover_papers(intent):
    """Find relevant papers from DynamoDB based on intent."""
    table = dynamodb.Table(PAPERS_TABLE)
    papers = []
    seen_ids = set()

    try:
        # Query by conditions
        for condition in intent.get("conditions", [])[:3]:
            response = table.query(
                KeyConditionExpression="PK = :pk",
                ExpressionAttributeValues={
                    ":pk": f"CONDITION#{condition.lower().replace(' ', '_')}",
                },
                ScanIndexForward=False,
                Limit=5,
            )
            for item in response.get("Items", []):
                pid = item.get("paper_id")
                if pid and pid not in seen_ids:
                    seen_ids.add(pid)
                    papers.append(item)

        # Query by drugs
        for drug in intent.get("drugs", [])[:2]:
            response = table.query(
                IndexName="DrugIndex",
                KeyConditionExpression="GSI1PK = :pk",
                ExpressionAttributeValues={
                    ":pk": f"DRUG#{drug.lower().replace(' ', '_')}",
                },
                ScanIndexForward=False,
                Limit=5,
            )
            for item in response.get("Items", []):
                pid = item.get("paper_id")
                if pid and pid not in seen_ids:
                    seen_ids.add(pid)
                    papers.append(item)

    except Exception as e:
        print(f"Paper discovery error: {e}")

    return papers[:10]


def _retrieve_rag_evidence(papers, query, intent):
    """Navigate tree structures to find relevant evidence using Tree RAG."""
    s3 = boto3.client("s3")
    bedrock = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)
    evidence = []

    for paper in papers[:5]:
        tree_key = paper.get("tree_s3_key")
        if not tree_key:
            continue

        try:
            obj = s3.get_object(Bucket=PAPERS_BUCKET, Key=tree_key)
            tree = json.loads(obj["Body"].read().decode("utf-8"))

            # Use Claude to navigate tree and extract findings
            tree_prompt = f"""You are navigating a research paper's tree structure to find evidence relevant to this query.

Query: {query}
Intent: {intent.get('intent_type', 'general')}

Paper tree structure:
{json.dumps(tree, indent=2)[:8000]}

Find the most relevant sections. Return JSON array:
[{{
    "finding": "specific finding text",
    "section": "section name (e.g., Results, Discussion)",
    "page": "page number if available",
    "relevance": "high/medium/low"
}}]

Only include findings directly relevant to the query. Max 3 findings per paper."""

            response = bedrock.invoke_model(
                modelId="anthropic.claude-3-5-haiku-20241022-v1:0",
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 2000,
                    "messages": [{"role": "user", "content": tree_prompt}],
                }),
            )
            result = json.loads(response["body"].read())
            text = result["content"][0]["text"]

            start = text.find("[")
            end = text.rfind("]") + 1
            if start >= 0 and end > start:
                findings = json.loads(text[start:end])
                for f in findings:
                    f["paper_id"] = paper.get("paper_id", "unknown")
                    f["paper_title"] = paper.get("title", "Unknown")
                    f["journal"] = paper.get("journal", "Unknown")
                    f["pub_date"] = paper.get("pub_date", "Unknown")
                    f["evidence_grade"] = paper.get("evidence_grade", "C")
                evidence.extend(findings)

        except Exception as e:
            print(f"RAG error for paper {paper.get('paper_id')}: {e}")

    return evidence


def _generate_response(message, history, evidence, intent):
    """Generate conversational response using Claude with full context."""
    bedrock = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)

    # Build conversation messages
    messages = []
    for turn in history[-MAX_HISTORY_TURNS * 2:]:
        messages.append({
            "role": turn["role"],
            "content": turn["content"],
        })

    # Build evidence context
    evidence_text = "No research papers found for this query."
    if evidence:
        evidence_items = []
        for e in evidence:
            grade = e.get("evidence_grade", "C")
            evidence_items.append(
                f"- **[{grade}]** {e.get('finding', 'N/A')} "
                f"(Source: {e.get('paper_title', 'Unknown')}, {e.get('journal', '')}, "
                f"{e.get('pub_date', '')}, Section: {e.get('section', 'N/A')})"
            )
        evidence_text = "\n".join(evidence_items)

    user_prompt = f"""Based on the following research evidence from indexed dermatology papers, answer the doctor's question.

**Retrieved Evidence:**
{evidence_text}

**Doctor's Question:** {message}

Provide a comprehensive, evidence-based response following the system rules."""

    messages.append({"role": "user", "content": user_prompt})

    # Choose model based on complexity
    model_id = "anthropic.claude-3-5-haiku-20241022-v1:0"
    max_tokens = 2000
    if intent.get("complexity") == "complex":
        model_id = "anthropic.claude-sonnet-4-20250514-v1:0"
        max_tokens = 3000

    try:
        response = bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": max_tokens,
                "system": SYSTEM_PROMPT,
                "messages": messages,
            }),
        )
        result = json.loads(response["body"].read())
        return result["content"][0]["text"]
    except Exception as e:
        print(f"Response generation error: {e}")
        return (
            "I apologize, but I encountered an error generating a response. "
            "Please try rephrasing your question.\n\n"
            "⚕️ Clinical decision support only - not a replacement for physician judgment."
        )


def _format_citations(evidence):
    """Format evidence into citation objects."""
    citations = []
    seen = set()
    for e in evidence:
        pid = e.get("paper_id", "unknown")
        if pid not in seen:
            seen.add(pid)
            citations.append({
                "paper_id": pid,
                "title": e.get("paper_title", "Unknown"),
                "journal": e.get("journal", "Unknown"),
                "year": e.get("pub_date", "Unknown")[:4] if e.get("pub_date") else "Unknown",
                "section": e.get("section", ""),
                "page": e.get("page", ""),
            })
    return citations


def _response(status_code, body):
    """Return API Gateway compatible response."""
    return {
        "statusCode": status_code,
        "headers": CORS_HEADERS,
        "body": json.dumps(body, default=str),
    }
