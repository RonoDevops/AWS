import React, { useState } from 'react';
import { Sparkles, Loader2 } from 'lucide-react';
import QueryInput from '../components/QueryInput';
import ResponseCard from '../components/ResponseCard';
import { useQuery } from '../hooks/useQuery';

const QUICK_FILTERS = [
  'Psoriasis',
  'Acne',
  'Atopic Dermatitis',
  'Dermatophytosis',
  'Vitiligo',
];

export default function QueryPage() {
  const { submitQuery, loading, error, data } = useQuery();
  const [activeFilter, setActiveFilter] = useState(null);

  const handleSubmit = async (queryText) => {
    try {
      await submitQuery(queryText, activeFilter);
    } catch {
      // Error is already set in the hook
    }
  };

  const handleFilterClick = (condition) => {
    setActiveFilter(activeFilter === condition ? null : condition);
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-8 sm:py-12">
      {/* Hero */}
      <div className="text-center mb-8">
        <div className="inline-flex items-center gap-2 bg-blue-50 text-blue-700 px-3 py-1.5 rounded-full text-xs font-medium mb-4">
          <Sparkles className="w-3.5 h-3.5" />
          AI-Powered Clinical Intelligence
        </div>
        <h1 className="text-3xl sm:text-4xl font-bold text-slate-800 mb-3">
          Dermatology Research Assistant
        </h1>
        <p className="text-slate-500 max-w-2xl mx-auto">
          Query evidence-based dermatology research. Get graded answers backed by peer-reviewed
          literature with full citations.
        </p>
      </div>

      {/* Search */}
      <div className="mb-6">
        <QueryInput onSubmit={handleSubmit} loading={loading} />
      </div>

      {/* Quick Filters */}
      <div className="flex flex-wrap items-center gap-2 mb-8 justify-center">
        <span className="text-xs text-slate-500 font-medium mr-1">Quick filters:</span>
        {QUICK_FILTERS.map((condition) => (
          <button
            key={condition}
            onClick={() => handleFilterClick(condition)}
            className={`px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
              activeFilter === condition
                ? 'bg-blue-600 text-white'
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            }`}
          >
            {condition}
          </button>
        ))}
      </div>

      {/* Loading */}
      {loading && (
        <div className="flex flex-col items-center justify-center py-16">
          <div className="relative">
            <div className="w-16 h-16 border-4 border-blue-100 rounded-full" />
            <div className="absolute inset-0 w-16 h-16 border-4 border-blue-600 rounded-full border-t-transparent animate-spin" />
          </div>
          <p className="mt-4 text-sm font-medium text-slate-600">Analyzing research papers...</p>
          <p className="mt-1 text-xs text-slate-400">Reviewing evidence from peer-reviewed literature</p>
        </div>
      )}

      {/* Error */}
      {error && !loading && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
          <p className="text-sm text-red-700">{error}</p>
        </div>
      )}

      {/* Response */}
      {data && !loading && <ResponseCard response={data} />}

      {/* Empty State */}
      {!data && !loading && !error && (
        <div className="text-center py-12">
          <div className="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <Sparkles className="w-7 h-7 text-slate-400" />
          </div>
          <p className="text-slate-500 text-sm">
            Enter a question about dermatology conditions, treatments, or drugs to get started.
          </p>
          <div className="mt-4 space-y-1">
            <p className="text-xs text-slate-400">Try asking:</p>
            <p className="text-xs text-blue-500 italic">
              &quot;What are the latest biologics for moderate-to-severe psoriasis?&quot;
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
