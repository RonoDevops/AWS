import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import ProtectedRoute from './components/ProtectedRoute';
import QueryPage from './pages/QueryPage';
import PapersPage from './pages/PapersPage';
import DashboardPage from './pages/DashboardPage';
import LoginPage from './pages/LoginPage';
import SignupPage from './pages/SignupPage';
import ChatPage from './pages/ChatPage';
import { useAuth } from './hooks/useAuth';

function AppContent() {
  const { isAuthenticated, loading, signOut } = useAuth();

  const handleLogout = async () => {
    try {
      await signOut();
    } catch {
      // Ignore sign-out errors
    }
  };

  return (
    <div className="min-h-screen bg-slate-50">
      <Navbar isAuthenticated={isAuthenticated} onLogout={handleLogout} />
      <main>
        <Routes>
          <Route path="/" element={<QueryPage />} />
          <Route
            path="/chat"
            element={
              <ProtectedRoute isAuthenticated={isAuthenticated} loading={loading}>
                <ChatPage />
              </ProtectedRoute>
            }
          />
          <Route path="/papers" element={<PapersPage />} />
          <Route
            path="/dashboard"
            element={
              <ProtectedRoute isAuthenticated={isAuthenticated} loading={loading}>
                <DashboardPage />
              </ProtectedRoute>
            }
          />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/signup" element={<SignupPage />} />
        </Routes>
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-200 mt-16 py-8 bg-white">
        <div className="max-w-7xl mx-auto px-4 text-center">
          <p className="text-xs text-slate-400">
            DermaIntel - AI Clinical Intelligence for Dermatology Research
          </p>
          <p className="text-xs text-slate-400 mt-1">
            For healthcare professional use only. Not a substitute for clinical judgment.
          </p>
        </div>
      </footer>
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AppContent />
    </BrowserRouter>
  );
}
