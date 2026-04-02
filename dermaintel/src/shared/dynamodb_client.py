"""DynamoDB helper functions for the DermaIntel project."""

import logging
import os

import boto3
from boto3.dynamodb.conditions import Key

logger = logging.getLogger(__name__)

_dynamodb = boto3.resource("dynamodb")


def _get_table():
    table_name = os.environ.get("PAPERS_TABLE_NAME", "DermaIntelPapers")
    return _dynamodb.Table(table_name)


def query_by_condition(
    condition: str,
    limit: int = 10,
    next_token: dict | None = None,
) -> dict:
    """Query papers by condition using the partition key PK=CONDITION#{condition}."""
    table = _get_table()
    kwargs: dict = {
        "KeyConditionExpression": Key("PK").eq(f"CONDITION#{condition}"),
        "Limit": limit,
    }
    if next_token:
        kwargs["ExclusiveStartKey"] = next_token

    response = table.query(**kwargs)
    return {
        "items": response.get("Items", []),
        "next_token": response.get("LastEvaluatedKey"),
    }


def query_by_drug(
    drug: str,
    limit: int = 10,
    next_token: dict | None = None,
) -> dict:
    """Query papers by drug using the DrugIndex GSI."""
    table = _get_table()
    kwargs: dict = {
        "IndexName": "DrugIndex",
        "KeyConditionExpression": Key("drug").eq(drug),
        "Limit": limit,
    }
    if next_token:
        kwargs["ExclusiveStartKey"] = next_token

    response = table.query(**kwargs)
    return {
        "items": response.get("Items", []),
        "next_token": response.get("LastEvaluatedKey"),
    }


def query_by_journal(
    journal: str,
    limit: int = 10,
    next_token: dict | None = None,
) -> dict:
    """Query papers by journal using the JournalIndex GSI."""
    table = _get_table()
    kwargs: dict = {
        "IndexName": "JournalIndex",
        "KeyConditionExpression": Key("journal").eq(journal),
        "Limit": limit,
    }
    if next_token:
        kwargs["ExclusiveStartKey"] = next_token

    response = table.query(**kwargs)
    return {
        "items": response.get("Items", []),
        "next_token": response.get("LastEvaluatedKey"),
    }


def put_paper_items(paper_metadata: dict) -> None:
    """Write paper items to DynamoDB, one item per condition.

    Each item has PK=CONDITION#{condition} and SK=PAPER#{paper_id}.
    """
    table = _get_table()
    paper_id = paper_metadata["paper_id"]
    conditions = paper_metadata.get("conditions", [])

    with table.batch_writer() as batch:
        for condition in conditions:
            item = {
                **paper_metadata,
                "PK": f"CONDITION#{condition}",
                "SK": f"PAPER#{paper_id}",
            }
            # Add GSI keys for drug and journal queries
            for drug in paper_metadata.get("drugs", []):
                drug_item = {
                    **item,
                    "drug": drug,
                }
                batch.put_item(Item=drug_item)
                # Only write the base item once per condition if no drugs
                item = None
                break
            if item is not None:
                batch.put_item(Item=item)

    logger.info("Wrote paper %s across %d conditions", paper_id, len(conditions))


def deduplicate_papers(papers: list[dict]) -> list[dict]:
    """Remove duplicate papers based on paper_id."""
    seen: set[str] = set()
    unique: list[dict] = []
    for paper in papers:
        pid = paper.get("paper_id", "")
        if pid not in seen:
            seen.add(pid)
            unique.append(paper)
    return unique


def get_paper(paper_id: str) -> dict | None:
    """Get a single paper by paper_id using the PaperIdIndex GSI."""
    table = _get_table()
    response = table.query(
        IndexName="PaperIdIndex",
        KeyConditionExpression=Key("paper_id").eq(paper_id),
        Limit=1,
    )
    items = response.get("Items", [])
    return items[0] if items else None
