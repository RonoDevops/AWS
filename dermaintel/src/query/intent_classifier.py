"""Intent classification for dermatology queries using Claude Haiku."""

import json
import logging

from shared.bedrock_client import invoke_model

logger = logging.getLogger(__name__)

CLASSIFICATION_PROMPT = """\
You are a dermatology query intent classifier. Analyze the following user query and extract structured intent information.

Return ONLY a valid JSON object with these fields:
- "conditions": list of strings - dermatological conditions mentioned (use canonical names like \
"atopic_dermatitis", "psoriasis", "acne_vulgaris", "melanoma", "rosacea", etc.)
- "drugs": list of strings - drugs or treatments mentioned (generic names, lowercase)
- "intent_type": string - one of: "diagnosis", "treatment_protocol", "drug_interaction", \
"research_update", "differential"
- "complexity": string - one of: "simple", "moderate", "complex"

Intent type definitions:
- diagnosis: Questions about identifying or confirming a condition
- treatment_protocol: Questions about treatment plans, dosing, or therapeutic approaches
- drug_interaction: Questions about drug interactions or contraindications
- research_update: Questions about latest research, clinical trials, or new findings
- differential: Questions about distinguishing between similar conditions

Complexity guide:
- simple: Single condition or drug, straightforward question
- moderate: Multiple conditions/drugs, or requires evidence synthesis
- complex: Drug interactions, differential diagnosis, or novel research interpretation

User query: {query}
"""


def classify_intent(query_text: str, model_id: str) -> dict:
    """Classify the intent of a dermatology query.

    Args:
        query_text: The user's query string.
        model_id: Bedrock model ID to use.

    Returns:
        Dict with conditions, drugs, intent_type, and complexity.
    """
    prompt = CLASSIFICATION_PROMPT.format(query=query_text)
    response_text = invoke_model(prompt, model_id=model_id, max_tokens=1024)

    # Parse JSON response
    cleaned = response_text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("\n", 1)[1] if "\n" in cleaned else cleaned[3:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

    try:
        result = json.loads(cleaned)
    except json.JSONDecodeError:
        logger.warning("Failed to parse intent classification JSON, using defaults")
        result = {
            "conditions": [],
            "drugs": [],
            "intent_type": "research_update",
            "complexity": "moderate",
        }

    # Validate and fill defaults
    result.setdefault("conditions", [])
    result.setdefault("drugs", [])
    result.setdefault("intent_type", "research_update")
    result.setdefault("complexity", "moderate")

    logger.info(
        "Classified intent: type=%s, complexity=%s, conditions=%s, drugs=%s",
        result["intent_type"],
        result["complexity"],
        result["conditions"],
        result["drugs"],
    )
    return result
