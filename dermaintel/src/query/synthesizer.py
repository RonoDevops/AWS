"""Evidence synthesizer: merge findings from multiple papers into a clinical response."""

import json
import logging

from shared.bedrock_client import invoke_model
from shared.constants import MEDICAL_DISCLAIMER
from shared.models import Citation, QueryResponse

logger = logging.getLogger(__name__)

SYNTHESIS_PROMPT = """\
You are a dermatology evidence synthesis expert. Given findings from multiple research \
papers and a user query, produce a comprehensive clinical response.

User query: {query}
Intent type: {intent_type}

Findings from papers:
{findings_text}

Instructions:
1. Synthesize the evidence across all papers into a coherent answer.
2. Grade the overall evidence quality:
   - "A" if supported by systematic reviews, meta-analyses, or RCTs
   - "B" if supported by cohort or case-control studies
   - "C" if only supported by case reports, expert opinion, or limited evidence
3. Flag any conflicting findings between papers.
4. Provide specific citations when making claims.
5. Be clinically precise but accessible.

Return ONLY a valid JSON object with:
- "answer": string - the synthesized clinical response (comprehensive, 2-5 paragraphs)
- "evidence_grade": string - "A", "B", or "C"
- "confidence": float between 0.0 and 1.0
- "conflicts": list of strings - any conflicting findings (empty if none)
- "citations_used": list of objects, each with "paper_id", "section", "page" fields
"""


def _format_findings(findings_by_paper: dict[str, list[dict]]) -> str:
    """Format findings from multiple papers into a readable block."""
    parts: list[str] = []
    for paper_id, findings in findings_by_paper.items():
        parts.append(f"\n=== Paper: {paper_id} ===")
        for i, finding in enumerate(findings, 1):
            section = finding.get("section_type", "unknown")
            title = finding.get("section_title", "")
            key_finding = finding.get("key_finding", "")
            content = finding.get("content_excerpt", "")
            pages = finding.get("page_numbers", [])

            parts.append(f"  Finding {i} [{section}: {title}] (pages {pages}):")
            if key_finding:
                parts.append(f"    Key finding: {key_finding}")
            if content:
                parts.append(f"    Content: {content[:500]}")

    return "\n".join(parts)


def _build_citations(
    synthesis_result: dict,
    findings_by_paper: dict[str, list[dict]],
    paper_metadata: dict[str, dict],
) -> list[Citation]:
    """Build Citation objects from synthesis results and paper metadata."""
    citations: list[Citation] = []
    seen: set[str] = set()

    for cite in synthesis_result.get("citations_used", []):
        paper_id = cite.get("paper_id", "")
        if not paper_id or paper_id in seen:
            continue
        seen.add(paper_id)

        meta = paper_metadata.get(paper_id, {})
        citations.append(
            Citation(
                paper_id=paper_id,
                title=meta.get("title", "Unknown"),
                journal=meta.get("journal", "Unknown"),
                year=meta.get("pub_date", "")[:4],
                section=cite.get("section", ""),
                page=cite.get("page", 0),
            )
        )

    # If model didn't return citations, create them from findings
    if not citations:
        for paper_id in findings_by_paper:
            if paper_id in seen:
                continue
            seen.add(paper_id)
            meta = paper_metadata.get(paper_id, {})
            findings = findings_by_paper[paper_id]
            first_finding = findings[0] if findings else {}
            pages = first_finding.get("page_numbers", [0])
            citations.append(
                Citation(
                    paper_id=paper_id,
                    title=meta.get("title", "Unknown"),
                    journal=meta.get("journal", "Unknown"),
                    year=meta.get("pub_date", "")[:4],
                    section=first_finding.get("section_type", ""),
                    page=pages[0] if pages else 0,
                )
            )

    return citations


def synthesize_evidence(
    findings_by_paper: dict[str, list[dict]],
    query: str,
    intent: dict,
    model_id: str,
    paper_metadata: dict[str, dict] | None = None,
) -> QueryResponse:
    """Synthesize evidence from multiple papers into a QueryResponse.

    Args:
        findings_by_paper: Dict mapping paper_id to list of findings.
        query: The original user query.
        intent: The classified intent dict.
        model_id: Bedrock model ID to use.
        paper_metadata: Optional dict mapping paper_id to paper metadata.

    Returns:
        A QueryResponse with synthesized answer and citations.
    """
    if paper_metadata is None:
        paper_metadata = {}

    findings_text = _format_findings(findings_by_paper)

    if not findings_text.strip():
        return QueryResponse(
            answer=(
                "I was unable to find specific research evidence to address your query. "
                "This may be because the topic is not well-covered in the indexed literature, "
                "or the query terms did not match any indexed papers. Please try rephrasing "
                f"your question or using more specific medical terminology.\n\n{MEDICAL_DISCLAIMER}"
            ),
            evidence_grade="C",
            citations=[],
            papers_consulted=0,
            confidence=0.0,
            model_used=model_id,
            query_time_ms=0,
        )

    prompt = SYNTHESIS_PROMPT.format(
        query=query,
        intent_type=intent.get("intent_type", "research_update"),
        findings_text=findings_text,
    )

    response_text = invoke_model(prompt, model_id=model_id, max_tokens=4096)

    # Parse JSON response
    cleaned = response_text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("\n", 1)[1] if "\n" in cleaned else cleaned[3:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

    try:
        synthesis = json.loads(cleaned)
    except json.JSONDecodeError:
        logger.warning("Failed to parse synthesis JSON, using raw text")
        synthesis = {
            "answer": response_text,
            "evidence_grade": "C",
            "confidence": 0.5,
            "conflicts": [],
            "citations_used": [],
        }

    # Build citations
    citations = _build_citations(synthesis, findings_by_paper, paper_metadata)

    # Append disclaimer and any conflict warnings
    answer = synthesis.get("answer", "")
    conflicts = synthesis.get("conflicts", [])
    if conflicts:
        conflict_text = "\n\nNote - Conflicting findings identified:\n" + "\n".join(
            f"- {c}" for c in conflicts
        )
        answer += conflict_text

    answer += f"\n\n{MEDICAL_DISCLAIMER}"

    model_label = "haiku" if "haiku" in model_id else "sonnet"

    return QueryResponse(
        answer=answer,
        evidence_grade=synthesis.get("evidence_grade", "C"),
        citations=citations,
        papers_consulted=len(findings_by_paper),
        confidence=float(synthesis.get("confidence", 0.5)),
        model_used=model_label,
        query_time_ms=0,  # Caller sets this
    )
