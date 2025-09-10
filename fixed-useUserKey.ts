import { useMemo, useCallback } from 'react';
import { EModelEndpoint, useUserKeyQuery, useUpdateUserKeysMutation, useFetchUserModelsMutation, useGetModelsQuery, QueryKeys } from 'librechat-data-provider/react-query';
import { useGetEndpointsQuery } from '~/data-provider';
import { useQueryClient } from '@tanstack/react-query';

const useUserKey = (endpoint: string) => {
  const { data: endpointsConfig } = useGetEndpointsQuery();
  const queryClient = useQueryClient();
  const { data: modelsData } = useGetModelsQuery();

  const config = endpointsConfig?.[endpoint ?? ''];
  let keyName = endpoint;

  if (config?.azure) {
    keyName = EModelEndpoint.azureOpenAI;
  } else if (keyName === EModelEndpoint.gptPlugins) {
    keyName = EModelEndpoint.openAI;
  }

  const updateKey = useUpdateUserKeysMutation();
  const fetchUserModels = useFetchUserModelsMutation();
  const checkUserKey = useUserKeyQuery(keyName);

  const getExpiry = useCallback(() => {
    if (checkUserKey.data) {
      return checkUserKey.data.expiresAt || 'never';
    }
  }, [checkUserKey.data]);

  const checkExpiry = useCallback(() => {
    const expiresAt = getExpiry();
    if (!expiresAt) {
      return true;
    }

    const expiresAtDate = new Date(expiresAt);
    if (expiresAtDate < new Date()) {
      return false;
    }
    return true;
  }, [getExpiry]);

  const saveUserKey = useCallback(
    async (userKey: string, expiresAt: number | null) => {
      console.log('[Dynamic Model Fetch] Starting saveUserKey for endpoint:', endpoint);

      const dateStr = expiresAt ? new Date(expiresAt).toISOString() : '';
      await updateKey.mutateAsync({
        name: keyName,
        value: userKey,
        expiresAt: dateStr,
      });

      console.log('[Dynamic Model Fetch] API key saved, checking if endpoint supports model fetching');

      // If this endpoint supports model fetching, fetch models after saving the key
      const endpointConfig = endpointsConfig?.[endpoint ?? ''];
      console.log('[Dynamic Model Fetch] Endpoint config:', endpointConfig);

      if (endpointConfig?.models?.fetch) {
        try {
          console.log('[Dynamic Model Fetch] Fetching models for endpoint:', endpoint);

          const result = await fetchUserModels.mutateAsync({ endpoint: endpoint });
          console.log('[Dynamic Model Fetch] Fetch result:', result);

          // Directly update the cache after successful fetch
          if (result && result.models) {
            console.log('[Dynamic Model Fetch] Updating cache directly with', result.models.length, 'models');

            const updatedModelsData = {
              ...modelsData,
              [endpoint]: result.models,
            };

            queryClient.setQueryData([QueryKeys.models], updatedModelsData);
            console.log('[Dynamic Model Fetch] Cache updated directly');

            // Also invalidate to trigger re-renders
            queryClient.invalidateQueries([QueryKeys.models]);
            console.log('[Dynamic Model Fetch] Cache invalidated');
          }

        } catch (error) {
          console.warn('[Dynamic Model Fetch] Failed to fetch models for endpoint:', endpoint, error);
        }
      } else {
        console.log('[Dynamic Model Fetch] Endpoint does not support model fetching:', endpointConfig);
      }
    },
    [updateKey, keyName, fetchUserModels, endpoint, endpointsConfig, modelsData, queryClient],
  );

  return useMemo(
    () => ({ getExpiry, checkExpiry, saveUserKey }),
    [getExpiry, checkExpiry, saveUserKey],
  );
};

export default useUserKey;