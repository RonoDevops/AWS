import React from 'react';
import { Calendar, BookOpen, ExternalLink } from 'lucide-react';

const GRADE_STYLES = {
  A: 'badge-green',
  B: 'badge-yellow',
  C: 'badge-orange',
};

export default function PaperCard({ paper }) {
  if (!paper) return null;

  const {
    title,
    authors = [],
    journal,
    date,
    evidence_grade,
    conditions = [],
    drugs = [],
    abstract,
    paper_id,
  } = paper;

  const truncatedAuthors =
    authors.length > 3
      ? `${authors.slice(0, 3).join(', ')} et al.`
      : authors.join(', ');

  const gradeStyle = GRADE_STYLES[evidence_grade] || 'badge-slate';

  return (
    <div className="card p-5 flex flex-col h-full">
      {/* Header */}
      <div className="flex items-start justify-between gap-3 mb-3">
        <h3 className="text-sm font-semibold text-slate-800 leading-snug line-clamp-2 flex-1">
          {title}
        </h3>
        {evidence_grade && (
          <span className={`${gradeStyle} flex-shrink-0`}>
            Grade {evidence_grade}
          </span>
        )}
      </div>

      {/* Authors */}
      {truncatedAuthors && (
        <p className="text-xs text-slate-500 mb-2">{truncatedAuthors}</p>
      )}

      {/* Journal & Date */}
      <div className="flex flex-wrap items-center gap-3 mb-3">
        {journal && (
          <span className="flex items-center gap-1 text-xs text-blue-600 font-medium">
            <BookOpen className="w-3.5 h-3.5" />
            {journal}
          </span>
        )}
        {date && (
          <span className="flex items-center gap-1 text-xs text-slate-500">
            <Calendar className="w-3.5 h-3.5" />
            {date}
          </span>
        )}
      </div>

      {/* Tags */}
      <div className="flex flex-wrap gap-1.5 mb-3">
        {conditions.map((c, i) => (
          <span key={i} className="badge-blue text-[10px]">{c}</span>
        ))}
        {drugs.map((d, i) => (
          <span key={i} className="badge-slate text-[10px]">{d}</span>
        ))}
      </div>

      {/* Abstract */}
      {abstract && (
        <p className="text-xs text-slate-600 leading-relaxed line-clamp-4 mb-4 flex-1">
          {abstract}
        </p>
      )}

      {/* View Details */}
      <div className="mt-auto pt-3 border-t border-slate-100">
        <button className="flex items-center gap-1.5 text-xs font-medium text-blue-600 hover:text-blue-700 transition-colors">
          <ExternalLink className="w-3.5 h-3.5" />
          View Details
        </button>
      </div>
    </div>
  );
}
