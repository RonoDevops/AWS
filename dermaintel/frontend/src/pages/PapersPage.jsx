import React, { useState, useEffect, useCallback } from 'react';
import { Filter, Search, Loader2 } from 'lucide-react';
import PaperCard from '../components/PaperCard';
import { useQuery } from '../hooks/useQuery';

const CONDITIONS = [
  'All Conditions',
  'Psoriasis',
  'Acne',
  'Atopic Dermatitis',
  'Dermatophytosis',
  'Vitiligo',
  'Rosacea',
  'Melanoma',
  'Eczema',
];

const STUDY_TYPES = [
  'All Types',
  'Randomized Controlled Trial',
  'Meta-Analysis',
  'Systematic Review',
  'Cohort Study',
  'Case Report',
];

export default function PapersPage() {
  const { listPapers, loading, error } = useQuery();
  const [papers, setPapers] = useState([]);
  const [filters, setFilters] = useState({
    condition: '',
    drug: '',
    journal: '',
    study_type: '',
  });
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [showFilters, setShowFilters] = useState(false);

  const fetchPapers = useCallback(async (resetPage = false) => {
    const currentPage = resetPage ? 1 : page;
    try {
      const activeFilters = {};
      Object.entries(filters).forEach(([key, value]) => {
        if (value && !value.startsWith('All')) {
          activeFilters[key] = value;
        }
      });
      activeFilters.page = currentPage;
      activeFilters.limit = 12;

      const result = await listPapers(activeFilters);
      const newPapers = result?.papers || result?.items || [];

      if (resetPage) {
        setPapers(newPapers);
        setPage(1);
      } else {
        setPapers((prev) => (currentPage === 1 ? newPapers : [...prev, ...newPapers]));
      }
      setHasMore(newPapers.length === 12);
    } catch {
      // Error handled by hook
    }
  }, [filters, page, listPapers]);

  useEffect(() => {
    fetchPapers(true);
  }, [filters]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleLoadMore = () => {
    setPage((p) => p + 1);
    fetchPapers(false);
  };

  const handleFilterChange = (key, value) => {
    setFilters((prev) => ({ ...prev, [key]: value }));
  };

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-800">Research Papers</h1>
          <p className="text-sm text-slate-500 mt-1">
            Browse and filter dermatology research literature
          </p>
        </div>
        <button
          onClick={() => setShowFilters(!showFilters)}
          className="sm:hidden btn-secondary flex items-center gap-2 text-sm"
        >
          <Filter className="w-4 h-4" />
          Filters
        </button>
      </div>

      <div className="flex gap-6">
        {/* Sidebar Filters */}
        <aside
          className={`w-64 flex-shrink-0 space-y-5 ${
            showFilters ? 'block' : 'hidden'
          } sm:block`}
        >
          <div className="card p-4 space-y-4 sticky top-20">
            <h3 className="text-sm font-semibold text-slate-800 flex items-center gap-2">
              <Filter className="w-4 h-4 text-blue-600" />
              Filters
            </h3>

            {/* Condition */}
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1.5">Condition</label>
              <select
                value={filters.condition}
                onChange={(e) => handleFilterChange('condition', e.target.value)}
                className="input-field text-sm py-2"
              >
                {CONDITIONS.map((c) => (
                  <option key={c} value={c === 'All Conditions' ? '' : c}>{c}</option>
                ))}
              </select>
            </div>

            {/* Drug Search */}
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1.5">Drug</label>
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-400" />
                <input
                  type="text"
                  value={filters.drug}
                  onChange={(e) => handleFilterChange('drug', e.target.value)}
                  placeholder="Search drug..."
                  className="input-field text-sm py-2 pl-9"
                />
              </div>
            </div>

            {/* Journal */}
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1.5">Journal</label>
              <input
                type="text"
                value={filters.journal}
                onChange={(e) => handleFilterChange('journal', e.target.value)}
                placeholder="Filter by journal..."
                className="input-field text-sm py-2"
              />
            </div>

            {/* Study Type */}
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1.5">Study Type</label>
              <select
                value={filters.study_type}
                onChange={(e) => handleFilterChange('study_type', e.target.value)}
                className="input-field text-sm py-2"
              >
                {STUDY_TYPES.map((t) => (
                  <option key={t} value={t === 'All Types' ? '' : t}>{t}</option>
                ))}
              </select>
            </div>

            {/* Clear */}
            <button
              onClick={() => setFilters({ condition: '', drug: '', journal: '', study_type: '' })}
              className="w-full text-xs text-blue-600 hover:text-blue-700 font-medium py-2"
            >
              Clear all filters
            </button>
          </div>
        </aside>

        {/* Papers Grid */}
        <div className="flex-1">
          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
              <p className="text-sm text-red-700">{error}</p>
            </div>
          )}

          {loading && papers.length === 0 ? (
            <div className="flex items-center justify-center py-20">
              <Loader2 className="w-8 h-8 text-blue-600 animate-spin" />
            </div>
          ) : papers.length === 0 ? (
            <div className="text-center py-20">
              <p className="text-slate-500 text-sm">No papers found matching your filters.</p>
            </div>
          ) : (
            <>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {papers.map((paper, idx) => (
                  <PaperCard key={paper.paper_id || idx} paper={paper} />
                ))}
              </div>

              {hasMore && (
                <div className="flex justify-center mt-8">
                  <button
                    onClick={handleLoadMore}
                    disabled={loading}
                    className="btn-secondary flex items-center gap-2"
                  >
                    {loading ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : null}
                    Load more
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
