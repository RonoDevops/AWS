"""Lambda handler: build PageIndex tree structure from paper PDFs."""

import json
import logging
import os

import fitz  # pymupdf

from shared.bedrock_client import invoke_model
from shared.constants import BEDROCK_MODELS
from shared.s3_client import download_file, upload_file

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}

TREE_SECTIONS = [
    "title",
    "abstract",
    "introduction",
    "methods",
    "results",
    "discussion",
    "conclusion",
    "references",
]

SECTION_EXTRACTION_PROMPT = """\
You are a biomedical paper parser. Given the following markdown text extracted from \
a dermatology research paper, identify and extract the main sections.

For each section found, output a JSON array where each element has:
- "type": one of {sections}
- "title": the section heading as written in the paper
- "content": the full text content of that section
- "page_numbers": list of page numbers where this section appears
- "children": list of subsections (same structure, can be empty)

If a section is not found in the paper, omit it.
Only output valid JSON, no other text.

Paper text:
{text}
"""

SUMMARY_PROMPT = """\
Summarize the following section of a dermatology research paper in 2-3 sentences. \
Focus on key findings, methods, or conclusions relevant to clinical dermatology.

Section type: {section_type}
Section title: {section_title}

Content:
{content}
"""


def _pdf_to_markdown(pdf_bytes: bytes) -> tuple[str, dict[int, str]]:
    """Convert PDF bytes to markdown text with page tracking.

    Returns:
        Tuple of (full_text, page_map) where page_map maps page numbers to text.
    """
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    page_map: dict[int, str] = {}
    full_parts: list[str] = []

    for page_num in range(len(doc)):
        page = doc.load_page(page_num)
        text = page.get_text("text")
        page_map[page_num + 1] = text
        full_parts.append(f"--- Page {page_num + 1} ---\n{text}")

    doc.close()
    return "\n\n".join(full_parts), page_map


def _extract_sections(markdown_text: str, model_id: str) -> list[dict]:
    """Use Claude Haiku to extract sections from paper text."""
    prompt = SECTION_EXTRACTION_PROMPT.format(
        sections=", ".join(TREE_SECTIONS),
        text=markdown_text[:30000],  # Limit input size
    )

    response_text = invoke_model(prompt, model_id=model_id, max_tokens=8192)

    # Parse JSON from response, handling potential markdown code blocks
    cleaned = response_text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("\n", 1)[1] if "\n" in cleaned else cleaned[3:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

    try:
        sections = json.loads(cleaned)
    except json.JSONDecodeError:
        logger.warning("Failed to parse section JSON, using fallback structure")
        sections = [
            {
                "type": "abstract",
                "title": "Full Paper",
                "content": markdown_text[:5000],
                "page_numbers": [1],
                "children": [],
            }
        ]

    return sections


def _summarize_sections(sections: list[dict], model_id: str) -> list[dict]:
    """Add LLM-generated summaries to each section node."""
    for section in sections:
        content = section.get("content", "")
        if content and len(content) > 50:
            prompt = SUMMARY_PROMPT.format(
                section_type=section.get("type", "unknown"),
                section_title=section.get("title", ""),
                content=content[:4000],
            )
            try:
                summary = invoke_model(prompt, model_id=model_id, max_tokens=512)
                section["summary"] = summary.strip()
            except Exception:
                logger.warning("Failed to summarize section %s", section.get("type"))
                section["summary"] = ""
        else:
            section["summary"] = ""

        # Recursively summarize children
        if section.get("children"):
            section["children"] = _summarize_sections(section["children"], model_id)

    return sections


def handler(event, context):
    """Lambda handler for building PageIndex tree from paper PDF.

    Event fields:
        paper_id: str - the paper identifier
        pdf_s3_key: str - S3 key of the PDF file
        bucket: str - S3 bucket name (optional, uses env default)
    """
    try:
        paper_id = event["paper_id"]
        pdf_s3_key = event.get("pdf_s3_key", "")
        bucket = event.get("bucket", os.environ.get("DATA_BUCKET", "dermaintel-data"))
        model_id = BEDROCK_MODELS["haiku"]

        if not pdf_s3_key:
            return {
                "statusCode": 400,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": "No PDF S3 key provided"}),
            }

        # Step 1: Download PDF from S3
        pdf_bytes = download_file(bucket, pdf_s3_key)
        logger.info("Downloaded PDF for %s (%d bytes)", paper_id, len(pdf_bytes))

        # Step 2: Convert to markdown
        markdown_text, page_map = _pdf_to_markdown(pdf_bytes)
        logger.info("Converted PDF to %d chars of markdown", len(markdown_text))

        # Step 3: Extract sections using Claude Haiku
        sections = _extract_sections(markdown_text, model_id)
        logger.info("Extracted %d sections", len(sections))

        # Step 4: Add LLM-generated summaries
        sections = _summarize_sections(sections, model_id)

        # Step 5: Build final tree structure
        tree = {
            "paper_id": paper_id,
            "total_pages": len(page_map),
            "sections": sections,
            "page_map": {str(k): v[:500] for k, v in page_map.items()},  # Truncate page previews
        }

        # Step 6: Upload tree JSON to S3
        safe_id = paper_id.replace(":", "_")
        tree_s3_key = f"papers/trees/{safe_id}.json"
        upload_file(bucket, tree_s3_key, json.dumps(tree, indent=2), "application/json")
        logger.info("Uploaded tree to s3://%s/%s", bucket, tree_s3_key)

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps({
                "paper_id": paper_id,
                "tree_s3_key": tree_s3_key,
                "section_count": len(sections),
            }),
        }

    except Exception as e:
        logger.error("Tree building failed for %s", event.get("paper_id", "unknown"), exc_info=True)
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(e)}),
        }
