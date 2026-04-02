import React, { useState } from 'react';
import { Search, Loader2 } from 'lucide-react';

export default function QueryInput({ onSubmit, loading, placeholder }) {
  const [query, setQuery] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    if (query.trim() && !loading) {
      onSubmit(query.trim());
    }
  };

  return (
    <form onSubmit={handleSubmit} className="w-full">
      <div className="relative">
        <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
          {loading ? (
            <Loader2 className="w-5 h-5 text-blue-500 animate-spin" />
          ) : (
            <Search className="w-5 h-5 text-slate-400" />
          )}
        </div>
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={placeholder || 'Ask about any dermatology condition, treatment, or drug...'}
          className="w-full pl-12 pr-32 py-4 text-lg border border-slate-300 rounded-xl
                     focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500
                     placeholder-slate-400 text-slate-700 bg-white shadow-sm"
          disabled={loading}
        />
        <div className="absolute inset-y-0 right-0 pr-2 flex items-center">
          <button
            type="submit"
            disabled={!query.trim() || loading}
            className="btn-primary px-6 py-2.5 text-sm"
          >
            {loading ? 'Searching...' : 'Search'}
          </button>
        </div>
      </div>
    </form>
  );
}
