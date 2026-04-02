"""Lambda handler: POST /feedback - submit query feedback."""

import json
import logging
import os
from datetime import datetime, timezone

import boto3

from shared.models import FeedbackRequest

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}

_dynamodb = boto3.resource("dynamodb")


def handler(event, context):
    """POST /feedback handler to record user feedback on query results."""
    try:
        # Parse and validate request body
        body = event.get("body", "{}")
        if isinstance(body, str):
            body = json.loads(body)

        try:
            feedback = FeedbackRequest(**body)
        except Exception as e:
            return {
                "statusCode": 400,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": f"Invalid feedback request: {e}"}),
            }

        # Write to feedback DynamoDB table
        table_name = os.environ.get("FEEDBACK_TABLE_NAME", "DermaIntelFeedback")
        table = _dynamodb.Table(table_name)

        now = datetime.now(timezone.utc).isoformat()
        item = {
            "PK": f"QUERY#{feedback.query_id}",
            "SK": f"FEEDBACK#{now}",
            "query_id": feedback.query_id,
            "rating": feedback.rating,
            "comment": feedback.comment or "",
            "created_at": now,
        }

        table.put_item(Item=item)
        logger.info("Recorded feedback for query %s: %s", feedback.query_id, feedback.rating)

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps({
                "message": "Feedback recorded successfully",
                "query_id": feedback.query_id,
            }),
        }

    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": "Invalid JSON in request body"}),
        }
    except Exception as e:
        logger.error("submit_feedback failed", exc_info=True)
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(e)}),
        }
