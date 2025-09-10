import { useEffect, useCallback, useMemo } from 'react';
import { useFetchUserModelsMutation, useGetModelsQuery } from 'librechat-data-provider/react-query';
import { useGetEndpointsQuery } from '~/data-provider';
import { useAuthContext } from '~/hooks/AuthContext';

const useAutoModelRefresh = () => {
  const { user } = useAuthContext();
  const { data: endpointsConfig } = useGetEndpointsQuery();
  const fetchUserModels = useFetchUserModelsMutation();
  const { refetch: refetchModels } = useGetModelsQuery();

  // Get all user-provided endpoints that support model fetching
  const userProvidedEndpoints = useMemo(() =>
    Object.entries(endpointsConfig || {})
      .filter(([_, config]) =>
        config?.apiKey === 'user_provided' &&
        config?.models?.fetch
      )
      .map(([endpoint]) => endpoint),
    [endpointsConfig]
  );

  const refreshUserModels = useCallback(async () => {
    if (!user || userProvidedEndpoints.length === 0) return;

    console.log('[Dynamic Model Fetch] Auto-refreshing models for user:', user.id);

    // For each user-provided endpoint, try to fetch models
    // The backend will check if the user has a key and return appropriate models
    const refreshPromises = userProvidedEndpoints.map(async (endpoint) => {
      try {
        console.log(`[Dynamic Model Fetch] Refreshing models for endpoint: ${endpoint}`);
        await fetchUserModels.mutateAsync({ endpoint });
      } catch (error) {
        // Silently fail - this is expected if user doesn't have a key
        console.debug(`No key available for endpoint ${endpoint}, skipping model fetch`);
      }
    });

    await Promise.all(refreshPromises);

    // Refresh the models cache
    await refetchModels();
  }, [user, userProvidedEndpoints, fetchUserModels, refetchModels]);

  // Auto-refresh models when user logs in or page loads
  useEffect(() => {
    if (user) {
      console.log('[Dynamic Model Fetch] User logged in, scheduling auto-refresh');

      // Small delay to ensure everything is initialized
      const timeoutId = setTimeout(() => {
        refreshUserModels();
      }, 1000);

      return () => clearTimeout(timeoutId);
    }
  }, [user, refreshUserModels]);

  // Also refresh models when the page becomes visible (e.g., tab switch)
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible' && user) {
        console.log('[Dynamic Model Fetch] Page became visible, checking for refresh');

        // Only refresh if it's been more than 5 minutes since last refresh
        const lastRefresh = localStorage.getItem('lastModelRefresh');
        const now = Date.now();
        if (!lastRefresh || (now - parseInt(lastRefresh)) > 5 * 60 * 1000) {
          localStorage.setItem('lastModelRefresh', now.toString());
          refreshUserModels();
        }
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [user, refreshUserModels]);

  return { refreshUserModels };
};

export default useAutoModelRefresh;

