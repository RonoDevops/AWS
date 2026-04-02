"""Lambda handler: GET /papers - list papers with filtering and pagination."""

import json
import logging

from shared.constants import CONDITION_ALIASES
from shared.dynamodb_client import (
    deduplicate_papers,
    query_by_condition,
    query_by_drug,
    query_by_journal,
)

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}


def handler(event, context):
    """GET /papers handler with query param filtering.

    Query params:
        condition: filter by condition name
        drug: filter by drug name
        journal: filter by journal
        study_type: filter by study type (post-query filter)
        limit: max results (default 20, max 100)
        next_token: pagination token (base64 JSON)
    """
    try:
        params = event.get("queryStringParameters") or {}
        condition = params.get("condition", "")
        drug = params.get("drug", "")
        journal = params.get("journal", "")
        study_type = params.get("study_type", "")
        limit = min(int(params.get("limit", "20")), 100)

        # Decode pagination token
        next_token = None
        raw_token = params.get("next_token", "")
        if raw_token:
            import base64
            try:
                next_token = json.loads(base64.b64decode(raw_token).decode())
            except Exception:
                return {
                    "statusCode": 400,
                    "headers": CORS_HEADERS,
                    "body": json.dumps({"error": "Invalid next_token"}),
                }

        # Route to appropriate query based on params
        if condition:
            canonical = CONDITION_ALIASES.get(condition.lower(), condition.lower())
            result = query_by_condition(canonical, limit=limit, next_token=next_token)
        elif drug:
            result = query_by_drug(drug.lower(), limit=limit, next_token=next_token)
        elif journal:
            result = query_by_journal(journal, limit=limit, next_token=next_token)
        else:
            # No filter - return error with guidance
            return {
                "statusCode": 400,
                "headers": CORS_HEADERS,
                "body": json.dumps({
                    "error": "At least one filter is required: condition, drug, or journal",
                }),
            }

        items = result["items"]

        # Post-query filter by study_type if specified
        if study_type:
            items = [p for p in items if p.get("study_type") == study_type]

        # Deduplicate
        items = deduplicate_papers(items)

        # Encode next_token for response
        encoded_token = None
        if result.get("next_token"):
            import base64
            encoded_token = base64.b64encode(json.dumps(result["next_token"]).encode()).decode()

        # Strip internal DynamoDB keys from response
        cleaned_items = []
        for item in items:
            cleaned = {k: v for k, v in item.items() if k not in ("PK", "SK")}
            cleaned_items.append(cleaned)

        response_body = {
            "papers": cleaned_items,
            "count": len(cleaned_items),
            "next_token": encoded_token,
        }

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps(response_body),
        }

    except Exception as e:
        logger.error("list_papers failed", exc_info=True)
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(e)}),
        }
