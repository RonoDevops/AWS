import { useState, useEffect, useCallback } from 'react';
import {
  signIn as amplifySignIn,
  signUp as amplifySignUp,
  signOut as amplifySignOut,
  confirmSignUp as amplifyConfirmSignUp,
  getCurrentUser as amplifyGetCurrentUser,
  fetchAuthSession,
} from '@aws-amplify/auth';

export function useAuth() {
  const [user, setUser] = useState(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const checkAuth = useCallback(async () => {
    try {
      const currentUser = await amplifyGetCurrentUser();
      setUser(currentUser);
      setIsAuthenticated(true);
    } catch {
      setUser(null);
      setIsAuthenticated(false);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  const signIn = async (email, password) => {
    setError(null);
    try {
      const result = await amplifySignIn({
        username: email,
        password,
      });
      if (result.isSignedIn) {
        await checkAuth();
      }
      return result;
    } catch (err) {
      setError(err.message || 'Sign in failed');
      throw err;
    }
  };

  const signUp = async (email, password) => {
    setError(null);
    try {
      const result = await amplifySignUp({
        username: email,
        password,
        options: {
          userAttributes: {
            email,
          },
        },
      });
      return result;
    } catch (err) {
      setError(err.message || 'Sign up failed');
      throw err;
    }
  };

  const confirmSignUp = async (email, code) => {
    setError(null);
    try {
      const result = await amplifyConfirmSignUp({
        username: email,
        confirmationCode: code,
      });
      return result;
    } catch (err) {
      setError(err.message || 'Confirmation failed');
      throw err;
    }
  };

  const signOut = async () => {
    setError(null);
    try {
      await amplifySignOut();
      setUser(null);
      setIsAuthenticated(false);
    } catch (err) {
      setError(err.message || 'Sign out failed');
      throw err;
    }
  };

  const getCurrentUser = async () => {
    try {
      return await amplifyGetCurrentUser();
    } catch {
      return null;
    }
  };

  const getToken = async () => {
    try {
      const session = await fetchAuthSession();
      return session.tokens?.idToken?.toString() || null;
    } catch {
      return null;
    }
  };

  return {
    user,
    isAuthenticated,
    loading,
    error,
    signIn,
    signUp,
    confirmSignUp,
    signOut,
    getCurrentUser,
    getToken,
  };
}
