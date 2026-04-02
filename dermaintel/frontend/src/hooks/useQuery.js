import { useState, useCallback } from 'react';
import { useAuth } from './useAuth';

const API_ENDPOINT = import.meta.env.VITE_API_ENDPOINT || '';

export function useQuery() {
  const { getToken } = useAuth();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [data, setData] = useState(null);

  const makeRequest = useCallback(async (path, options = {}) => {
    const token = await getToken();
    const headers = {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    };

    const response = await fetch(`${API_ENDPOINT}${path}`, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}));
      throw new Error(errorBody.message || `Request failed with status ${response.status}`);
    }

    return response.json();
  }, [getToken]);

  const submitQuery = useCallback(async (queryText, condition = null) => {
    setLoading(true);
    setError(null);
    setData(null);
    const startTime = Date.now();

    try {
      const body = { query: queryText };
      if (condition) body.condition = condition;

      const result = await makeRequest('/query', {
        method: 'POST',
        body: JSON.stringify(body),
      });

      const queryTime = ((Date.now() - startTime) / 1000).toFixed(1);
      const enrichedResult = { ...result, queryTime };
      setData(enrichedResult);
      return enrichedResult;
    } catch (err) {
      setError(err.message || 'Query failed');
      throw err;
    } finally {
      setLoading(false);
    }
  }, [makeRequest]);

  const listPapers = useCallback(async (filters = {}) => {
    setLoading(true);
    setError(null);

    try {
      const params = new URLSearchParams();
      Object.entries(filters).forEach(([key, value]) => {
        if (value) params.append(key, value);
      });

      const queryString = params.toString();
      const path = `/papers${queryString ? `?${queryString}` : ''}`;
      const result = await makeRequest(path);
      setData(result);
      return result;
    } catch (err) {
      setError(err.message || 'Failed to load papers');
      throw err;
    } finally {
      setLoading(false);
    }
  }, [makeRequest]);

  const getPaper = useCallback(async (paperId) => {
    setLoading(true);
    setError(null);

    try {
      const result = await makeRequest(`/papers/${paperId}`);
      setData(result);
      return result;
    } catch (err) {
      setError(err.message || 'Failed to load paper');
      throw err;
    } finally {
      setLoading(false);
    }
  }, [makeRequest]);

  const listConditions = useCallback(async () => {
    try {
      return await makeRequest('/conditions');
    } catch (err) {
      setError(err.message || 'Failed to load conditions');
      throw err;
    }
  }, [makeRequest]);

  const submitFeedback = useCallback(async (feedback) => {
    try {
      return await makeRequest('/feedback', {
        method: 'POST',
        body: JSON.stringify(feedback),
      });
    } catch (err) {
      setError(err.message || 'Failed to submit feedback');
      throw err;
    }
  }, [makeRequest]);

  const sendChatMessage = useCallback(async (message, sessionId = null) => {
    setLoading(true);
    setError(null);

    try {
      const body = { message };
      if (sessionId) body.session_id = sessionId;

      const result = await makeRequest('/chat', {
        method: 'POST',
        body: JSON.stringify(body),
      });
      return result;
    } catch (err) {
      setError(err.message || 'Chat failed');
      throw err;
    } finally {
      setLoading(false);
    }
  }, [makeRequest]);

  const getChatHistory = useCallback(async (sessionId = null, limit = 20) => {
    try {
      const params = new URLSearchParams();
      if (sessionId) params.append('session_id', sessionId);
      params.append('limit', limit.toString());
      return await makeRequest(`/chat/history?${params.toString()}`);
    } catch (err) {
      setError(err.message || 'Failed to load chat history');
      throw err;
    }
  }, [makeRequest]);

  const clearError = useCallback(() => setError(null), []);
  const clearData = useCallback(() => setData(null), []);

  return {
    loading,
    error,
    data,
    submitQuery,
    listPapers,
    getPaper,
    listConditions,
    submitFeedback,
    sendChatMessage,
    getChatHistory,
    clearError,
    clearData,
  };
}
