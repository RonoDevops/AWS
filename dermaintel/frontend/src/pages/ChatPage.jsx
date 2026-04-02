import { useState, useRef, useEffect } from 'react';
import { useAuth } from '../hooks/useAuth';
import { useNavigate } from 'react-router-dom';

const MEDICAL_DISCLAIMER = 'Clinical decision support only - not a replacement for physician judgment.';

const QUICK_PROMPTS = [
  'What are the latest biologics for moderate-to-severe psoriasis?',
  'First-line treatment for acne vulgaris in adolescents?',
  'Dupilumab vs JAK inhibitors for atopic dermatitis?',
  'Differential diagnosis for hypopigmented macules?',
  'Drug interactions with methotrexate in dermatology?',
];

export default function ChatPage() {
  const { isAuthenticated, getToken } = useAuth();
  const navigate = useNavigate();
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [sessionId, setSessionId] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef(null);
  const inputRef = useRef(null);

  useEffect(() => {
    if (!isAuthenticated) {
      navigate('/login');
    }
  }, [isAuthenticated, navigate]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const sendMessage = async (text) => {
    if (!text.trim() || isLoading) return;

    const userMessage = {
      id: Date.now(),
      role: 'user',
      content: text.trim(),
      timestamp: new Date().toISOString(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);

    try {
      const token = await getToken();
      const apiEndpoint = import.meta.env.VITE_API_ENDPOINT;

      const res = await fetch(`${apiEndpoint}/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          message: text.trim(),
          session_id: sessionId,
        }),
      });

      if (!res.ok) {
        throw new Error(`API error: ${res.status}`);
      }

      const data = await res.json();

      if (data.session_id && !sessionId) {
        setSessionId(data.session_id);
      }

      const assistantMessage = {
        id: Date.now() + 1,
        role: 'assistant',
        content: data.response,
        citations: data.citations || [],
        papersConsulted: data.papers_consulted || 0,
        confidence: data.confidence || 'medium',
        intent: data.intent || {},
        timestamp: data.timestamp || new Date().toISOString(),
      };

      setMessages((prev) => [...prev, assistantMessage]);
    } catch (err) {
      const errorMessage = {
        id: Date.now() + 1,
        role: 'assistant',
        content: 'I apologize, but I encountered an error. Please try again.',
        isError: true,
        timestamp: new Date().toISOString(),
      };
      setMessages((prev) => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
      inputRef.current?.focus();
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    sendMessage(input);
  };

  const startNewChat = () => {
    setMessages([]);
    setSessionId(null);
    setInput('');
  };

  return (
    <div className="flex flex-col h-[calc(100vh-64px)] bg-slate-50">
      {/* Chat Header */}
      <div className="bg-white border-b border-slate-200 px-6 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center">
            <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z" />
            </svg>
          </div>
          <div>
            <h2 className="font-semibold text-slate-800">DermaIntel AI Assistant</h2>
            <p className="text-xs text-slate-500">RAG-powered clinical intelligence</p>
          </div>
        </div>
        <button
          onClick={startNewChat}
          className="text-sm text-blue-600 hover:text-blue-700 font-medium px-3 py-1.5 rounded-md hover:bg-blue-50 transition-colors"
        >
          + New Chat
        </button>
      </div>

      {/* Messages Area */}
      <div className="flex-1 overflow-y-auto px-4 py-6 space-y-6">
        {messages.length === 0 && (
          <div className="flex flex-col items-center justify-center h-full text-center">
            <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mb-4">
              <svg className="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
              </svg>
            </div>
            <h3 className="text-lg font-semibold text-slate-700 mb-2">Ask me about dermatology</h3>
            <p className="text-sm text-slate-500 mb-6 max-w-md">
              I analyze the latest research papers to provide evidence-based answers with citations and evidence grading.
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 max-w-2xl w-full">
              {QUICK_PROMPTS.map((prompt, i) => (
                <button
                  key={i}
                  onClick={() => sendMessage(prompt)}
                  className="text-left text-sm px-4 py-3 bg-white rounded-lg border border-slate-200 hover:border-blue-300 hover:bg-blue-50 transition-colors text-slate-600"
                >
                  {prompt}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((msg) => (
          <ChatMessage key={msg.id} message={msg} />
        ))}

        {isLoading && (
          <div className="flex items-start gap-3 max-w-3xl mx-auto">
            <div className="w-8 h-8 bg-blue-600 rounded-full flex-shrink-0 flex items-center justify-center">
              <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <div className="bg-white rounded-lg px-4 py-3 shadow-sm border border-slate-100">
              <div className="flex items-center gap-2 text-sm text-slate-500">
                <div className="flex gap-1">
                  <span className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                  <span className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                  <span className="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
                </div>
                Analyzing research papers...
              </div>
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Disclaimer */}
      <div className="px-4 py-1 text-center">
        <p className="text-xs text-slate-400">{MEDICAL_DISCLAIMER}</p>
      </div>

      {/* Input Area */}
      <div className="bg-white border-t border-slate-200 px-4 py-3">
        <form onSubmit={handleSubmit} className="max-w-3xl mx-auto flex gap-3">
          <input
            ref={inputRef}
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Ask about conditions, treatments, drug interactions..."
            className="flex-1 px-4 py-3 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
            disabled={isLoading}
          />
          <button
            type="submit"
            disabled={!input.trim() || isLoading}
            className="px-6 py-3 bg-blue-600 text-white rounded-lg font-medium text-sm hover:bg-blue-700 disabled:bg-slate-300 disabled:cursor-not-allowed transition-colors"
          >
            Send
          </button>
        </form>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Chat Message Component
// ---------------------------------------------------------------------------
function ChatMessage({ message }) {
  const [showCitations, setShowCitations] = useState(false);
  const isUser = message.role === 'user';

  const confidenceColors = {
    high: 'bg-green-100 text-green-700',
    medium: 'bg-yellow-100 text-yellow-700',
    low: 'bg-red-100 text-red-700',
  };

  const gradeColors = {
    A: 'bg-green-500',
    B: 'bg-yellow-500',
    C: 'bg-orange-500',
  };

  return (
    <div className={`flex items-start gap-3 max-w-3xl mx-auto ${isUser ? 'flex-row-reverse' : ''}`}>
      {/* Avatar */}
      <div className={`w-8 h-8 rounded-full flex-shrink-0 flex items-center justify-center ${
        isUser ? 'bg-slate-600' : message.isError ? 'bg-red-500' : 'bg-blue-600'
      }`}>
        {isUser ? (
          <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
        ) : (
          <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
          </svg>
        )}
      </div>

      {/* Message Content */}
      <div className={`flex-1 ${isUser ? 'text-right' : ''}`}>
        <div className={`inline-block text-left rounded-lg px-4 py-3 shadow-sm text-sm leading-relaxed ${
          isUser
            ? 'bg-blue-600 text-white'
            : message.isError
              ? 'bg-red-50 text-red-700 border border-red-200'
              : 'bg-white text-slate-700 border border-slate-100'
        }`}>
          <div className="whitespace-pre-wrap">{message.content}</div>
        </div>

        {/* Metadata bar for assistant messages */}
        {!isUser && !message.isError && message.citations && (
          <div className="mt-2 flex flex-wrap items-center gap-2">
            {message.confidence && (
              <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${confidenceColors[message.confidence] || confidenceColors.medium}`}>
                {message.confidence.toUpperCase()} confidence
              </span>
            )}
            {message.papersConsulted > 0 && (
              <span className="text-xs text-slate-500">
                {message.papersConsulted} papers analyzed
              </span>
            )}
            {message.citations.length > 0 && (
              <button
                onClick={() => setShowCitations(!showCitations)}
                className="text-xs text-blue-600 hover:text-blue-700 font-medium"
              >
                {showCitations ? 'Hide' : 'Show'} {message.citations.length} citation{message.citations.length !== 1 ? 's' : ''}
              </button>
            )}
          </div>
        )}

        {/* Citations panel */}
        {showCitations && message.citations && message.citations.length > 0 && (
          <div className="mt-2 bg-slate-50 rounded-lg p-3 border border-slate-200">
            <h4 className="text-xs font-semibold text-slate-600 mb-2">References</h4>
            <ul className="space-y-1.5">
              {message.citations.map((cite, i) => (
                <li key={i} className="flex items-start gap-2 text-xs text-slate-600">
                  <span className={`w-5 h-5 rounded flex-shrink-0 flex items-center justify-center text-white text-[10px] font-bold ${gradeColors[cite.evidence_grade] || 'bg-slate-400'}`}>
                    {cite.evidence_grade || '?'}
                  </span>
                  <span>
                    <strong>{cite.title}</strong>
                    {cite.journal && ` - ${cite.journal}`}
                    {cite.year && ` (${cite.year})`}
                    {cite.section && <span className="text-slate-400"> | {cite.section}</span>}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </div>
  );
}
