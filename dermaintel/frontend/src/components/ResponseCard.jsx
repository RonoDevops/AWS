import React, { useState } from 'react';
import {
  ChevronDown,
  ChevronUp,
  BookOpen,
  Clock,
  AlertTriangle,
  ShieldCheck,
  Cpu,
} from 'lucide-react';

const GRADE_STYLES = {
  A: 'badge-green',
  B: 'badge-yellow',
  C: 'badge-orange',
};

const GRADE_LABELS = {
  A: 'Strong Evidence',
  B: 'Moderate Evidence',
  C: 'Limited Evidence',
};

function ConfidenceMeter({ confidence }) {
  const percent = Math.round((confidence || 0) * 100);
  const color =
    percent >= 80 ? 'bg-emerald-500' :
    percent >= 60 ? 'bg-amber-500' :
    'bg-orange-500';

  return (
    <div className="flex items-center gap-3">
      <span className="text-xs text-slate-500 font-medium">Confidence</span>
      <div className="flex-1 h-2 bg-slate-100 rounded-full overflow-hidden">
        <div
          className={`h-full rounded-full transition-all duration-500 ${color}`}
          style={{ width: `${percent}%` }}
        />
      </div>
      <span className="text-xs font-semibold text-slate-600">{percent}%</span>
    </div>
  );
}

function FormattedAnswer({ text }) {
  if (!text) return null;

  const paragraphs = text.split('\n\n').filter(Boolean);
  return (
    <div className="prose prose-slate prose-sm max-w-none">
      {paragraphs.map((para, i) => {
        if (para.startsWith('- ') || para.startsWith('* ')) {
          const items = para.split('\n').filter(Boolean);
          return (
            <ul key={i} className="list-disc pl-5 space-y-1">
              {items.map((item, j) => (
                <li key={j}>{item.replace(/^[-*]\s*/, '')}</li>
              ))}
            </ul>
          );
        }
        if (para.startsWith('# ')) {
          return <h3 key={i} className="text-lg font-semibold mt-4">{para.replace(/^#+\s*/, '')}</h3>;
        }
        if (para.startsWith('## ')) {
          return <h4 key={i} className="text-base font-semibold mt-3">{para.replace(/^#+\s*/, '')}</h4>;
        }
        return <p key={i} className="leading-relaxed">{para}</p>;
      })}
    </div>
  );
}

export default function ResponseCard({ response }) {
  const [showCitations, setShowCitations] = useState(false);

  if (!response) return null;

  const {
    answer,
    evidence_grade,
    citations = [],
    confidence,
    papers_consulted,
    queryTime,
    model,
  } = response;

  const gradeStyle = GRADE_STYLES[evidence_grade] || 'badge-slate';
  const gradeLabel = GRADE_LABELS[evidence_grade] || 'Ungraded';

  return (
    <div className="card p-6 space-y-5">
      {/* Header */}
      <div className="flex flex-wrap items-center gap-3">
        <span className={gradeStyle}>
          <ShieldCheck className="w-3.5 h-3.5 mr-1" />
          Grade {evidence_grade} - {gradeLabel}
        </span>
        {papers_consulted && (
          <span className="badge-blue">
            <BookOpen className="w-3.5 h-3.5 mr-1" />
            {papers_consulted} papers consulted
          </span>
        )}
        {queryTime && (
          <span className="badge-slate">
            <Clock className="w-3.5 h-3.5 mr-1" />
            {queryTime}s
          </span>
        )}
        {model && (
          <span className="badge-slate">
            <Cpu className="w-3.5 h-3.5 mr-1" />
            {model}
          </span>
        )}
      </div>

      {/* Confidence */}
      {confidence != null && <ConfidenceMeter confidence={confidence} />}

      {/* Answer */}
      <div className="bg-slate-50 rounded-lg p-5">
        <FormattedAnswer text={answer} />
      </div>

      {/* Citations */}
      {citations.length > 0 && (
        <div className="border border-slate-200 rounded-lg">
          <button
            onClick={() => setShowCitations(!showCitations)}
            className="w-full flex items-center justify-between px-4 py-3 text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors rounded-lg"
          >
            <span className="flex items-center gap-2">
              <BookOpen className="w-4 h-4 text-blue-600" />
              Citations ({citations.length})
            </span>
            {showCitations ? (
              <ChevronUp className="w-4 h-4" />
            ) : (
              <ChevronDown className="w-4 h-4" />
            )}
          </button>
          {showCitations && (
            <div className="px-4 pb-4 space-y-3 border-t border-slate-100">
              {citations.map((citation, idx) => (
                <div key={idx} className="flex gap-3 pt-3">
                  <span className="flex-shrink-0 w-6 h-6 bg-blue-100 text-blue-700 rounded-full flex items-center justify-center text-xs font-semibold">
                    {idx + 1}
                  </span>
                  <div className="text-sm">
                    <p className="font-medium text-slate-800">
                      {citation.title || citation}
                    </p>
                    {citation.journal && (
                      <p className="text-slate-500 mt-0.5">
                        {citation.journal}
                        {citation.year ? ` (${citation.year})` : ''}
                      </p>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Disclaimer */}
      <div className="flex items-start gap-2 bg-amber-50 border border-amber-200 rounded-lg p-4">
        <AlertTriangle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
        <p className="text-xs text-amber-800 leading-relaxed">
          <strong>Medical Disclaimer:</strong> This information is generated by AI from published
          research and is intended for healthcare professional reference only. It does not constitute
          medical advice. Always verify findings against primary sources and apply clinical judgment
          when making treatment decisions.
        </p>
      </div>
    </div>
  );
}
