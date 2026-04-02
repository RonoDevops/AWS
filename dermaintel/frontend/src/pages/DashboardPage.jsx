import React, { useState, useEffect } from 'react';
import {
  Activity,
  Clock,
  Star,
  BarChart3,
  Search,
  Bookmark,
  ChevronRight,
} from 'lucide-react';
import { useAuth } from '../hooks/useAuth';

const TIER_LIMITS = {
  free: 10,
  professional: 100,
  enterprise: 1000,
};

const TIER_COLORS = {
  free: 'badge-slate',
  professional: 'badge-blue',
  enterprise: 'badge-green',
};

export default function DashboardPage() {
  const { user } = useAuth();
  const [stats, setStats] = useState({
    queriesUsed: 0,
    tier: 'free',
    recentQueries: [],
    savedResponses: [],
  });

  useEffect(() => {
    // In a real app, fetch from API. Using placeholder data for now.
    setStats({
      queriesUsed: 3,
      tier: 'free',
      recentQueries: [
        {
          id: '1',
          query: 'Latest biologics for psoriasis treatment',
          timestamp: new Date(Date.now() - 3600000).toISOString(),
          evidenceGrade: 'A',
        },
        {
          id: '2',
          query: 'Topical retinoids for acne vulgaris',
          timestamp: new Date(Date.now() - 7200000).toISOString(),
          evidenceGrade: 'A',
        },
        {
          id: '3',
          query: 'Phototherapy protocols for vitiligo',
          timestamp: new Date(Date.now() - 86400000).toISOString(),
          evidenceGrade: 'B',
        },
      ],
      savedResponses: [
        {
          id: '1',
          query: 'Dupilumab efficacy in atopic dermatitis',
          savedAt: new Date(Date.now() - 172800000).toISOString(),
        },
      ],
    });
  }, []);

  const queryLimit = TIER_LIMITS[stats.tier] || 10;
  const tierColor = TIER_COLORS[stats.tier] || 'badge-slate';
  const usagePercent = Math.round((stats.queriesUsed / queryLimit) * 100);

  const formatTime = (isoString) => {
    const date = new Date(isoString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    return `${diffDays}d ago`;
  };

  const gradeStyle = (grade) => {
    if (grade === 'A') return 'badge-green';
    if (grade === 'B') return 'badge-yellow';
    return 'badge-orange';
  };

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      {/* Welcome */}
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <h1 className="text-2xl font-bold text-slate-800">Dashboard</h1>
          <span className={`${tierColor} capitalize`}>{stats.tier}</span>
        </div>
        <p className="text-sm text-slate-500">
          Welcome back, {user?.signInDetails?.loginId || user?.username || 'Clinician'}
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <div className="card p-5">
          <div className="flex items-center gap-3 mb-3">
            <div className="p-2 bg-blue-50 rounded-lg">
              <Activity className="w-5 h-5 text-blue-600" />
            </div>
            <span className="text-sm font-medium text-slate-600">Queries Today</span>
          </div>
          <div className="flex items-end gap-2">
            <span className="text-3xl font-bold text-slate-800">{stats.queriesUsed}</span>
            <span className="text-sm text-slate-500 mb-1">/ {queryLimit}</span>
          </div>
          <div className="mt-3 h-2 bg-slate-100 rounded-full overflow-hidden">
            <div
              className={`h-full rounded-full transition-all ${
                usagePercent > 80 ? 'bg-red-500' : 'bg-blue-500'
              }`}
              style={{ width: `${Math.min(usagePercent, 100)}%` }}
            />
          </div>
        </div>

        <div className="card p-5">
          <div className="flex items-center gap-3 mb-3">
            <div className="p-2 bg-emerald-50 rounded-lg">
              <BarChart3 className="w-5 h-5 text-emerald-600" />
            </div>
            <span className="text-sm font-medium text-slate-600">Total Queries</span>
          </div>
          <span className="text-3xl font-bold text-slate-800">
            {stats.recentQueries.length}
          </span>
        </div>

        <div className="card p-5">
          <div className="flex items-center gap-3 mb-3">
            <div className="p-2 bg-amber-50 rounded-lg">
              <Star className="w-5 h-5 text-amber-600" />
            </div>
            <span className="text-sm font-medium text-slate-600">Saved Responses</span>
          </div>
          <span className="text-3xl font-bold text-slate-800">
            {stats.savedResponses.length}
          </span>
        </div>
      </div>

      {/* Recent Queries & Saved */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Queries */}
        <div className="card">
          <div className="flex items-center gap-2 px-5 py-4 border-b border-slate-100">
            <Search className="w-4 h-4 text-blue-600" />
            <h2 className="text-sm font-semibold text-slate-800">Recent Queries</h2>
          </div>
          <div className="divide-y divide-slate-50">
            {stats.recentQueries.length === 0 ? (
              <div className="px-5 py-8 text-center">
                <p className="text-sm text-slate-400">No queries yet</p>
              </div>
            ) : (
              stats.recentQueries.map((q) => (
                <div
                  key={q.id}
                  className="px-5 py-3 flex items-center gap-3 hover:bg-slate-50 transition-colors cursor-pointer"
                >
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-slate-700 truncate">{q.query}</p>
                    <div className="flex items-center gap-2 mt-1">
                      <span className="flex items-center gap-1 text-xs text-slate-400">
                        <Clock className="w-3 h-3" />
                        {formatTime(q.timestamp)}
                      </span>
                      <span className={`${gradeStyle(q.evidenceGrade)} text-[10px]`}>
                        Grade {q.evidenceGrade}
                      </span>
                    </div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-slate-300" />
                </div>
              ))
            )}
          </div>
        </div>

        {/* Saved Responses */}
        <div className="card">
          <div className="flex items-center gap-2 px-5 py-4 border-b border-slate-100">
            <Bookmark className="w-4 h-4 text-amber-600" />
            <h2 className="text-sm font-semibold text-slate-800">Saved Responses</h2>
          </div>
          <div className="divide-y divide-slate-50">
            {stats.savedResponses.length === 0 ? (
              <div className="px-5 py-8 text-center">
                <p className="text-sm text-slate-400">No saved responses</p>
              </div>
            ) : (
              stats.savedResponses.map((s) => (
                <div
                  key={s.id}
                  className="px-5 py-3 flex items-center gap-3 hover:bg-slate-50 transition-colors cursor-pointer"
                >
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-slate-700 truncate">{s.query}</p>
                    <span className="text-xs text-slate-400 flex items-center gap-1 mt-1">
                      <Clock className="w-3 h-3" />
                      Saved {formatTime(s.savedAt)}
                    </span>
                  </div>
                  <ChevronRight className="w-4 h-4 text-slate-300" />
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
