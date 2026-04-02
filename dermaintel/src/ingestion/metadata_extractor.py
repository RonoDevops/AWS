"""Lambda handler: extract structured metadata from papers using Claude Haiku."""

import json
import logging
import os

from shared.bedrock_client import invoke_model
from shared.constants import BEDROCK_MODELS, EVIDENCE_GRADES
from shared.dynamodb_client import put_paper_items
from shared.s3_client import download_json

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}

EXTRACTION_PROMPT = """\
You are a biomedical metadata extraction system. Analyze the following dermatology \
research paper text and extract structured metadata.

Return ONLY a valid JSON object with these fields:
- "title": string - the paper title
- "authors": list of strings - author names in "LastName FirstName" format
- "journal": string - journal name
- "pub_date": string - publication date (YYYY or YYYY-MM-DD)
- "conditions": list of strings - dermatological conditions studied (use canonical names like \
"atopic_dermatitis", "psoriasis", "acne_vulgaris", "melanoma", etc.)
- "drugs": list of strings - drugs/treatments mentioned (generic names, lowercase)
- "study_type": string - one of: systematic_review, meta_analysis, rct, cohort_study, \
case_control, cross_sectional, case_series, case_report, narrative_review, expert_opinion, \
in_vitro, animal_study
- "outcomes": string - brief summary of primary outcomes/findings (1-2 sentences)
- "abstract_summary": string - concise summary of the paper (3-4 sentences)

Paper text (first ~4000 tokens):
{text}
"""


def _truncate_to_tokens(text: str, max_tokens: int = 4000) -> str:
    """Approximate token truncation (rough: 1 token ~ 4 chars)."""
    max_chars = max_tokens * 4
    if len(text) <= max_chars:
        return text
    return text[:max_chars]


def _extract_text_from_tree(tree: dict) -> str:
    """Extract the first ~4000 tokens of text from a tree structure."""
    parts: list[str] = []
    for section in tree.get("sections", []):
        section_type = section.get("type", "")
        content = section.get("content", "")
        if content:
            parts.append(f"[{section_type}]\n{content}")
        for child in section.get("children", []):
            child_content = child.get("content", "")
            if child_content:
                parts.append(child_content)
    full_text = "\n\n".join(parts)
    return _truncate_to_tokens(full_text)


def handler(event, context):
    """Lambda handler for metadata extraction.

    Event fields:
        paper_id: str - the paper identifier
        tree_s3_key: str - S3 key of the tree JSON
        bucket: str - S3 bucket name (optional)
    """
    try:
        paper_id = event["paper_id"]
        tree_s3_key = event.get("tree_s3_key", "")
        pdf_s3_key = event.get("pdf_s3_key", "")
        bucket = event.get("bucket", os.environ.get("DATA_BUCKET", "dermaintel-data"))
        model_id = BEDROCK_MODELS["haiku"]

        if not tree_s3_key:
            return {
                "statusCode": 400,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": "No tree S3 key provided"}),
            }

        # Step 1: Load tree from S3
        tree = download_json(bucket, tree_s3_key)
        logger.info("Loaded tree for %s with %d sections", paper_id, len(tree.get("sections", [])))

        # Step 2: Extract text (first ~4000 tokens)
        paper_text = _extract_text_from_tree(tree)
        if not paper_text:
            return {
                "statusCode": 400,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": "No text content found in tree"}),
            }

        # Step 3: Single Claude Haiku call for structured extraction
        prompt = EXTRACTION_PROMPT.format(text=paper_text)
        response_text = invoke_model(prompt, model_id=model_id, max_tokens=2048)

        # Parse JSON response
        cleaned = response_text.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1] if "\n" in cleaned else cleaned[3:]
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3]
            cleaned = cleaned.strip()

        extracted = json.loads(cleaned)

        # Step 4: Determine evidence grade from study type
        study_type = extracted.get("study_type", "narrative_review")
        evidence_grade = EVIDENCE_GRADES.get(study_type, "C")

        # Step 5: Build full metadata
        metadata = {
            "paper_id": paper_id,
            "title": extracted.get("title", ""),
            "authors": extracted.get("authors", []),
            "journal": extracted.get("journal", ""),
            "pub_date": extracted.get("pub_date", ""),
            "conditions": extracted.get("conditions", []),
            "drugs": extracted.get("drugs", []),
            "study_type": study_type,
            "evidence_grade": evidence_grade,
            "outcomes": extracted.get("outcomes", ""),
            "abstract_summary": extracted.get("abstract_summary", ""),
            "tree_s3_key": tree_s3_key,
            "pdf_s3_key": pdf_s3_key,
        }

        # Step 6: Write to DynamoDB (one item per condition)
        put_paper_items(metadata)
        logger.info(
            "Wrote metadata for %s: %d conditions, %d drugs",
            paper_id,
            len(metadata["conditions"]),
            len(metadata["drugs"]),
        )

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps({"paper_id": paper_id, "metadata": metadata}),
        }

    except json.JSONDecodeError as e:
        logger.error("Failed to parse extraction response for %s", event.get("paper_id", "unknown"), exc_info=True)
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": f"Metadata extraction failed: invalid JSON from model: {e}"}),
        }
    except Exception as e:
        logger.error("Metadata extraction failed for %s", event.get("paper_id", "unknown"), exc_info=True)
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(e)}),
        }
