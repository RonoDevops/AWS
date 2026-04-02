import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Stethoscope, Search, FileText, LayoutDashboard, LogIn, LogOut, MessageCircle } from 'lucide-react';

export default function Navbar({ isAuthenticated, onLogout }) {
  const location = useLocation();

  const navLinks = [
    { to: '/', label: 'Query', icon: Search },
    { to: '/chat', label: 'AI Chat', icon: MessageCircle },
    { to: '/papers', label: 'Papers', icon: FileText },
    { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  ];

  const isActive = (path) => location.pathname === path;

  return (
    <nav className="bg-white border-b border-slate-200 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link to="/" className="flex items-center gap-2 group">
            <div className="p-1.5 bg-blue-600 rounded-lg group-hover:bg-blue-700 transition-colors">
              <Stethoscope className="w-5 h-5 text-white" />
            </div>
            <span className="text-xl font-bold text-slate-800">
              Derma<span className="text-blue-600">Intel</span>
            </span>
          </Link>

          {/* Nav Links */}
          <div className="hidden sm:flex items-center gap-1">
            {navLinks.map(({ to, label, icon: Icon }) => (
              <Link
                key={to}
                to={to}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  isActive(to)
                    ? 'bg-blue-50 text-blue-600'
                    : 'text-slate-600 hover:text-slate-800 hover:bg-slate-50'
                }`}
              >
                <Icon className="w-4 h-4" />
                {label}
              </Link>
            ))}
          </div>

          {/* Auth */}
          <div className="flex items-center">
            {isAuthenticated ? (
              <button
                onClick={onLogout}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-slate-600 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
              >
                <LogOut className="w-4 h-4" />
                Logout
              </button>
            ) : (
              <Link
                to="/login"
                className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  isActive('/login')
                    ? 'bg-blue-50 text-blue-600'
                    : 'text-slate-600 hover:text-slate-800 hover:bg-slate-50'
                }`}
              >
                <LogIn className="w-4 h-4" />
                Login
              </Link>
            )}
          </div>
        </div>
      </div>

      {/* Mobile nav */}
      <div className="sm:hidden border-t border-slate-100 px-2 py-2 flex gap-1">
        {navLinks.map(({ to, label, icon: Icon }) => (
          <Link
            key={to}
            to={to}
            className={`flex-1 flex flex-col items-center gap-1 py-2 rounded-lg text-xs font-medium transition-colors ${
              isActive(to)
                ? 'bg-blue-50 text-blue-600'
                : 'text-slate-500 hover:text-slate-700'
            }`}
          >
            <Icon className="w-4 h-4" />
            {label}
          </Link>
        ))}
      </div>
    </nav>
  );
}
