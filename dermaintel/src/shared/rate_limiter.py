"""Rate limiter using DynamoDB conditional writes for atomic increment."""

import logging
import os
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Attr

logger = logging.getLogger(__name__)

_dynamodb = boto3.resource("dynamodb")

TIER_LIMITS: dict[str, int | None] = {
    "free": 5,
    "pro": 50,
    "premium": None,  # unlimited
}


def _get_table():
    table_name = os.environ.get("RATE_LIMIT_TABLE_NAME", "DermaIntelRateLimits")
    return _dynamodb.Table(table_name)


def check_rate_limit(user_id: str, tier: str) -> bool:
    """Check whether a user is within their rate limit for today.

    Uses DynamoDB conditional writes for atomic increment.

    Args:
        user_id: The user identifier.
        tier: One of 'free', 'pro', 'premium'.

    Returns:
        True if the request is allowed, False if rate-limited.
    """
    max_requests = TIER_LIMITS.get(tier)
    if max_requests is None:
        return True

    table = _get_table()
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    pk = f"USER#{user_id}"
    sk = f"DATE#{today}"

    try:
        table.update_item(
            Key={"PK": pk, "SK": sk},
            UpdateExpression="SET request_count = if_not_exists(request_count, :zero) + :inc",
            ConditionExpression=(
                Attr("request_count").not_exists() | Attr("request_count").lt(max_requests)
            ),
            ExpressionAttributeValues={
                ":zero": 0,
                ":inc": 1,
            },
        )
        return True
    except _dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
        logger.info("Rate limit exceeded for user %s (tier=%s, limit=%d/day)", user_id, tier, max_requests)
        return False
    except Exception:
        logger.warning("Rate limit check failed for user %s, allowing request", user_id, exc_info=True)
        return True
