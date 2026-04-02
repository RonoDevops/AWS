"""Lambda handler: GET /conditions - list all indexed conditions with paper counts."""

import json
import logging
import os

import boto3
from boto3.dynamodb.conditions import Key

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Cache-Control": "public, max-age=300",
}

_dynamodb = boto3.resource("dynamodb")


def _scan_conditions() -> list[dict]:
    """Scan the table for all unique CONDITION# partition keys with counts."""
    table_name = os.environ.get("PAPERS_TABLE_NAME", "DermaIntelPapers")
    table = _dynamodb.Table(table_name)

    condition_counts: dict[str, int] = {}
    last_key = None

    while True:
        kwargs: dict = {
            "ProjectionExpression": "PK",
            "FilterExpression": Key("PK").begins_with("CONDITION#"),
        }
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key

        response = table.scan(**kwargs)

        for item in response.get("Items", []):
            pk = item.get("PK", "")
            condition = pk.replace("CONDITION#", "")
            if condition:
                condition_counts[condition] = condition_counts.get(condition, 0) + 1

        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            break

    # Sort by count descending
    sorted_conditions = sorted(condition_counts.items(), key=lambda x: x[1], reverse=True)
    return [{"condition": name, "paper_count": count} for name, count in sorted_conditions]


def handler(event, context):
    """GET /conditions handler returning all indexed conditions with paper counts."""
    try:
        conditions = _scan_conditions()

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps({
                "conditions": conditions,
                "total": len(conditions),
            }),
        }

    except Exception as e:
        logger.error("list_conditions failed", exc_info=True)
        return {
            "statusCode": 500,
            "headers": {k: v for k, v in CORS_HEADERS.items() if k != "Cache-Control"},
            "body": json.dumps({"error": str(e)}),
        }
