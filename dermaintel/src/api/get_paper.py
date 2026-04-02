"""Lambda handler: GET /papers/{paper_id} - get full paper details."""

import json
import logging
import os

from shared.dynamodb_client import get_paper
from shared.s3_client import download_json

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}


def handler(event, context):
    """GET /papers/{paper_id} handler.

    Path params:
        paper_id: the paper identifier

    Query params:
        include_tree: if "true", include the full tree structure from S3
    """
    try:
        # Extract paper_id from path parameters
        path_params = event.get("pathParameters") or {}
        paper_id = path_params.get("paper_id", "")

        if not paper_id:
            return {
                "statusCode": 400,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": "paper_id is required"}),
            }

        # Fetch paper metadata from DynamoDB
        paper = get_paper(paper_id)
        if not paper:
            return {
                "statusCode": 404,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": f"Paper {paper_id} not found"}),
            }

        # Strip internal DynamoDB keys
        result = {k: v for k, v in paper.items() if k not in ("PK", "SK")}

        # Optionally include tree structure
        params = event.get("queryStringParameters") or {}
        include_tree = params.get("include_tree", "").lower() == "true"

        if include_tree:
            tree_s3_key = paper.get("tree_s3_key", "")
            if tree_s3_key:
                bucket = os.environ.get("DATA_BUCKET", "dermaintel-data")
                try:
                    tree = download_json(bucket, tree_s3_key)
                    result["tree"] = tree
                except Exception:
                    logger.warning("Failed to load tree for %s", paper_id, exc_info=True)
                    result["tree"] = None
                    result["tree_error"] = "Tree structure could not be loaded"

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps(result),
        }

    except Exception as e:
        logger.error("get_paper failed", exc_info=True)
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(e)}),
        }
