import React from 'react';
import { Navigate } from 'react-router-dom';
import { Loader2 } from 'lucide-react';

export default function ProtectedRoute({ isAuthenticated, loading, children }) {
  if (loading) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <Loader2 className="w-8 h-8 text-blue-600 animate-spin" />
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return children;
}
