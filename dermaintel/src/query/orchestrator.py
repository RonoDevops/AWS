"""Main query Lambda handler: 4-step RAG pipeline for dermatology queries."""

import json
import logging
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

from shared.bedrock_client import invoke_model
from shared.constants import BEDROCK_MODELS, CONDITION_ALIASES
from shared.dynamodb_client import deduplicate_papers, query_by_condition, query_by_drug
from shared.models import QueryRequest
from shared.s3_client import download_json

from query.intent_classifier import classify_intent
from query.synthesizer import synthesize_evidence
from query.tree_navigator import navigate_tree

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}


def _resolve_model_id(preference: str | None, complexity: str) -> str:
    """Choose model based on user preference and query complexity."""
    if preference and preference in BEDROCK_MODELS:
        return BEDROCK_MODELS[preference]
    # Use Sonnet for complex queries, Haiku for everything else
    if complexity == "complex":
        return BEDROCK_MODELS["sonnet"]
    return BEDROCK_MODELS["haiku"]


def _discover_papers(intent: dict, limit: int = 10) -> tuple[list[dict], dict[str, dict]]:
    """Discover relevant papers based on classified intent.

    Returns:
        Tuple of (paper_list, metadata_by_paper_id).
    """
    all_papers: list[dict] = []

    # Query by conditions
    for condition in intent.get("conditions", []):
        canonical = CONDITION_ALIASES.get(condition.lower(), condition.lower())
        result = query_by_condition(canonical, limit=limit)
        all_papers.extend(result["items"])

    # Query by drugs
    for drug in intent.get("drugs", []):
        result = query_by_drug(drug.lower(), limit=limit)
        all_papers.extend(result["items"])

    # Deduplicate
    papers = deduplicate_papers(all_papers)
    logger.info("Discovered %d unique papers (from %d total)", len(papers), len(all_papers))

    # Build metadata lookup
    metadata_map = {p.get("paper_id", ""): p for p in papers if p.get("paper_id")}
    return papers, metadata_map


def _navigate_paper(paper: dict, query: str, model_id: str, bucket: str) -> tuple[str, list[dict]]:
    """Navigate a single paper's tree (for parallel execution)."""
    paper_id = paper.get("paper_id", "")
    tree_s3_key = paper.get("tree_s3_key", "")
    if not tree_s3_key:
        return paper_id, []

    try:
        tree_json = download_json(bucket, tree_s3_key)
        findings = navigate_tree(tree_json, query, model_id)
        return paper_id, findings
    except Exception:
        logger.warning("Failed to navigate tree for paper %s", paper_id, exc_info=True)
        return paper_id, []


def handler(event, context):
    """Main query Lambda handler implementing 4-step RAG pipeline.

    Accepts API Gateway HTTP API event with JSON body containing QueryRequest fields.
    Pipeline: intent classification -> paper discovery -> parallel tree RAG -> synthesis.
    """
    start_time = time.time()

    try:
        # Parse request
        body = event.get("body", "{}")
        if isinstance(body, str):
            body = json.loads(body)
        request = QueryRequest(**body)

        bucket = os.environ.get("DATA_BUCKET", "dermaintel-data")

        # Step 1: Intent Classification (using Haiku for speed)
        logger.info("Step 1: Classifying intent for query: %s", request.query[:100])
        intent = classify_intent(request.query, model_id=BEDROCK_MODELS["haiku"])

        # Resolve which model to use for synthesis
        model_id = _resolve_model_id(request.model_preference, intent["complexity"])
        logger.info("Using model: %s (complexity=%s)", model_id, intent["complexity"])

        # Step 2: Paper Discovery
        logger.info("Step 2: Discovering papers")
        papers, metadata_map = _discover_papers(intent)

        if not papers:
            elapsed_ms = int((time.time() - start_time) * 1000)
            result = {
                "answer": (
                    "No relevant papers were found for your query. "
                    "Try using more specific dermatological terms or condition names."
                ),
                "evidence_grade": "C",
                "citations": [],
                "papers_consulted": 0,
                "confidence": 0.0,
                "model_used": "haiku" if "haiku" in model_id else "sonnet",
                "query_time_ms": elapsed_ms,
            }
            return {
                "statusCode": 200,
                "headers": CORS_HEADERS,
                "body": json.dumps(result),
            }

        # Step 3: Parallel Tree RAG
        logger.info("Step 3: Navigating %d paper trees in parallel", len(papers))
        findings_by_paper: dict[str, list[dict]] = {}

        with ThreadPoolExecutor(max_workers=min(len(papers), 5)) as executor:
            futures = {
                executor.submit(_navigate_paper, paper, request.query, model_id, bucket): paper
                for paper in papers[:10]  # Cap at 10 papers
            }
            for future in as_completed(futures):
                paper_id, findings = future.result()
                if findings:
                    findings_by_paper[paper_id] = findings

        logger.info("Step 3 complete: findings from %d papers", len(findings_by_paper))

        # Step 4: Synthesis
        logger.info("Step 4: Synthesizing evidence")
        query_response = synthesize_evidence(
            findings_by_paper=findings_by_paper,
            query=request.query,
            intent=intent,
            model_id=model_id,
            paper_metadata=metadata_map,
        )

        # Set query time
        elapsed_ms = int((time.time() - start_time) * 1000)
        query_response.query_time_ms = elapsed_ms

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": query_response.model_dump_json(),
        }

    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": "Invalid JSON in request body"}),
        }
    except Exception as e:
        logger.error("Query pipeline failed", exc_info=True)
        elapsed_ms = int((time.time() - start_time) * 1000)
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(e), "query_time_ms": elapsed_ms}),
        }
