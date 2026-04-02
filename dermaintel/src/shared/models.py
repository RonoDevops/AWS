"""Pydantic v2 models for the DermaIntel project."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class PaperMetadata(BaseModel):
    paper_id: str
    title: str
    authors: list[str]
    journal: str
    pub_date: str
    conditions: list[str]
    drugs: list[str]
    study_type: str
    evidence_grade: str
    outcomes: str
    abstract_summary: str
    tree_s3_key: str = ""
    pdf_s3_key: str = ""
    created_at: str = Field(default_factory=lambda: datetime.now().isoformat())


class Citation(BaseModel):
    paper_id: str
    title: str
    journal: str
    year: str
    section: str
    page: int


class QueryRequest(BaseModel):
    query: str
    model_preference: Literal["haiku", "sonnet"] | None = None


class QueryResponse(BaseModel):
    answer: str
    evidence_grade: str
    citations: list[Citation]
    papers_consulted: int
    confidence: float
    model_used: str
    query_time_ms: int


class FeedbackRequest(BaseModel):
    query_id: str
    rating: Literal["helpful", "not_helpful", "incorrect"]
    comment: str | None = None
