"""Tree navigator: LLM-driven traversal of paper tree structures for RAG."""

import json
import logging

from shared.bedrock_client import invoke_model

logger = logging.getLogger(__name__)

NAVIGATION_PROMPT = """\
You are a biomedical research navigator. Given a paper's section tree and a user query, \
identify the most relevant sections that contain evidence to answer the query.

User query: {query}

Paper title: {paper_title}
Paper ID: {paper_id}

Available sections (with summaries):
{section_summaries}

Return ONLY a valid JSON array of up to 5 relevant findings. Each finding should have:
- "section_type": the section type (e.g., "results", "methods", "discussion")
- "section_title": the exact section title
- "relevance": string explaining why this section is relevant (1 sentence)
- "key_finding": string with the most important finding from this section (1-2 sentences)
- "page_numbers": list of page numbers

Only include sections that are genuinely relevant to the query. Return an empty array [] \
if no sections are relevant.
"""


def _format_section_summaries(sections: list[dict], depth: int = 0) -> str:
    """Format section tree into a readable summary list."""
    lines: list[str] = []
    indent = "  " * depth
    for section in sections:
        section_type = section.get("type", "unknown")
        title = section.get("title", "")
        summary = section.get("summary", "")
        pages = section.get("page_numbers", [])
        content_preview = section.get("content", "")[:200]

        line = f"{indent}- [{section_type}] {title} (pages: {pages})"
        if summary:
            line += f"\n{indent}  Summary: {summary}"
        elif content_preview:
            line += f"\n{indent}  Preview: {content_preview}..."
        lines.append(line)

        for child in section.get("children", []):
            lines.extend(_format_section_summaries([child], depth + 1).splitlines())

    return "\n".join(lines)


def _extract_findings_with_content(findings: list[dict], sections: list[dict]) -> list[dict]:
    """Enrich findings with actual section content for citation."""
    section_lookup: dict[str, dict] = {}

    def _index_sections(secs: list[dict]) -> None:
        for s in secs:
            key = s.get("type", "")
            section_lookup[key] = s
            title_key = s.get("title", "").lower()
            if title_key:
                section_lookup[title_key] = s
            for child in s.get("children", []):
                _index_sections([child])

    _index_sections(sections)

    enriched: list[dict] = []
    for finding in findings[:5]:  # Max 5 per paper
        section_type = finding.get("section_type", "")
        matched = section_lookup.get(section_type) or section_lookup.get(
            finding.get("section_title", "").lower()
        )
        if matched:
            finding["content_excerpt"] = matched.get("content", "")[:1000]
        enriched.append(finding)

    return enriched


def navigate_tree(tree_json: dict, query: str, model_id: str) -> list[dict]:
    """Navigate a paper's tree structure to find relevant findings.

    Args:
        tree_json: The paper's tree structure (from S3).
        query: The user's query string.
        model_id: Bedrock model ID to use.

    Returns:
        List of finding dicts with section citations and content excerpts.
    """
    paper_id = tree_json.get("paper_id", "unknown")
    sections = tree_json.get("sections", [])

    if not sections:
        logger.info("No sections in tree for paper %s", paper_id)
        return []

    # Build section summaries for the prompt
    summaries_text = _format_section_summaries(sections)

    # Determine paper title from first section or metadata
    paper_title = "Unknown"
    for s in sections:
        if s.get("type") == "title":
            paper_title = s.get("content", s.get("title", "Unknown"))
            break

    prompt = NAVIGATION_PROMPT.format(
        query=query,
        paper_title=paper_title,
        paper_id=paper_id,
        section_summaries=summaries_text,
    )

    response_text = invoke_model(prompt, model_id=model_id, max_tokens=2048)

    # Parse JSON response
    cleaned = response_text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("\n", 1)[1] if "\n" in cleaned else cleaned[3:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

    try:
        findings = json.loads(cleaned)
        if not isinstance(findings, list):
            findings = []
    except json.JSONDecodeError:
        logger.warning("Failed to parse navigation findings for %s", paper_id)
        findings = []

    # Enrich findings with actual content
    findings = _extract_findings_with_content(findings, sections)

    # Tag each finding with paper_id
    for finding in findings:
        finding["paper_id"] = paper_id

    logger.info("Found %d relevant sections in paper %s", len(findings), paper_id)
    return findings
