"""Bedrock invoke_model wrapper with retry and CloudWatch metrics."""

import json
import logging
import time

import boto3
from botocore.exceptions import ClientError

from shared.constants import BEDROCK_MODELS

logger = logging.getLogger(__name__)

_bedrock_client = boto3.client("bedrock-runtime")
_cloudwatch_client = boto3.client("cloudwatch")


def _put_token_metrics(input_tokens: int, output_tokens: int, model_id: str) -> None:
    """Publish token usage metrics to CloudWatch."""
    try:
        model_label = "haiku" if "haiku" in model_id else "sonnet"
        _cloudwatch_client.put_metric_data(
            Namespace="DermaIntel/Bedrock",
            MetricData=[
                {
                    "MetricName": "InputTokens",
                    "Dimensions": [{"Name": "Model", "Value": model_label}],
                    "Value": float(input_tokens),
                    "Unit": "Count",
                },
                {
                    "MetricName": "OutputTokens",
                    "Dimensions": [{"Name": "Model", "Value": model_label}],
                    "Value": float(output_tokens),
                    "Unit": "Count",
                },
            ],
        )
    except Exception:
        logger.warning("Failed to publish CloudWatch metrics", exc_info=True)


def invoke_model(
    prompt: str,
    model_id: str | None = None,
    max_tokens: int = 4096,
    system_prompt: str | None = None,
) -> str:
    """Invoke a Bedrock model with retry and exponential backoff.

    Args:
        prompt: The user prompt text.
        model_id: Full Bedrock model ID. Defaults to Haiku.
        max_tokens: Maximum tokens in the response.
        system_prompt: Optional system prompt.

    Returns:
        The parsed response text from the model.

    Raises:
        RuntimeError: If all retry attempts are exhausted.
    """
    if model_id is None:
        model_id = BEDROCK_MODELS["haiku"]

    messages = [{"role": "user", "content": [{"type": "text", "text": prompt}]}]

    body: dict = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": max_tokens,
        "messages": messages,
    }
    if system_prompt:
        body["system"] = [{"type": "text", "text": system_prompt}]

    max_attempts = 3
    for attempt in range(1, max_attempts + 1):
        try:
            response = _bedrock_client.invoke_model(
                modelId=model_id,
                contentType="application/json",
                accept="application/json",
                body=json.dumps(body),
            )
            result = json.loads(response["body"].read())

            input_tokens = result.get("usage", {}).get("input_tokens", 0)
            output_tokens = result.get("usage", {}).get("output_tokens", 0)
            _put_token_metrics(input_tokens, output_tokens, model_id)

            return result["content"][0]["text"]

        except ClientError as exc:
            error_code = exc.response["Error"]["Code"]
            if error_code in ("ThrottlingException", "ServiceUnavailableException") and attempt < max_attempts:
                wait = 2 ** (attempt - 1)
                logger.warning("Bedrock call attempt %d failed (%s), retrying in %ds", attempt, error_code, wait)
                time.sleep(wait)
            else:
                raise RuntimeError(f"Bedrock invocation failed after {attempt} attempts: {exc}") from exc
        except Exception as exc:
            if attempt < max_attempts:
                wait = 2 ** (attempt - 1)
                logger.warning("Bedrock call attempt %d failed, retrying in %ds", attempt, wait)
                time.sleep(wait)
            else:
                raise RuntimeError(f"Bedrock invocation failed after {attempt} attempts: {exc}") from exc

    raise RuntimeError("Bedrock invocation failed: exhausted all retry attempts")
