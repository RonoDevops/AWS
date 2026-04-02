"""S3 helper functions for the DermaIntel project."""

import json
import logging

import boto3

logger = logging.getLogger(__name__)

_s3_client = boto3.client("s3")


def upload_file(bucket: str, key: str, body: bytes | str, content_type: str) -> None:
    """Upload a file to S3."""
    if isinstance(body, str):
        body = body.encode("utf-8")
    _s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=body,
        ContentType=content_type,
    )
    logger.info("Uploaded s3://%s/%s (%d bytes)", bucket, key, len(body))


def download_file(bucket: str, key: str) -> bytes:
    """Download a file from S3 and return its bytes."""
    response = _s3_client.get_object(Bucket=bucket, Key=key)
    data = response["Body"].read()
    logger.info("Downloaded s3://%s/%s (%d bytes)", bucket, key, len(data))
    return data


def download_json(bucket: str, key: str) -> dict:
    """Download a JSON file from S3 and return it as a dict."""
    data = download_file(bucket, key)
    return json.loads(data.decode("utf-8"))


def generate_presigned_url(bucket: str, key: str, expiry: int = 3600) -> str:
    """Generate a presigned URL for an S3 object.

    Args:
        bucket: S3 bucket name.
        key: S3 object key.
        expiry: URL expiration time in seconds (default 1 hour).

    Returns:
        Presigned URL string.
    """
    url = _s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": bucket, "Key": key},
        ExpiresIn=expiry,
    )
    return url
