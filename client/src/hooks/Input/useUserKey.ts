import { useMemo, useCallback } from 'react';
import { EModelEndpoint } from 'librechat-data-provider';
import { useUserKeyQuery, useUpdateUserKeysMutation } from 'librechat-data-provider/react-query';
import { useGetEndpointsQuery } from '~/data-provider';

// Import useFetchUserModelsMutation from the main package
import { useFetchUserModelsMutation } from 'librechat-data-provider';

const useUserKey = (endpoint: string) => {
  const { data: endpointsConfig } = useGetEndpointsQuery();
  const config = endpointsConfig?.[endpoint ?? ''];

  const { azure } = config ?? {};
  let keyName = endpoint;

  if (azure) {
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
      const dateStr = expiresAt ? new Date(expiresAt).toISOString() : '';
      await updateKey.mutateAsync({
        name: keyName,
        value: userKey,
        expiresAt: dateStr,
      });

      // If this endpoint supports model fetching, fetch models after saving the key
      const endpointConfig = endpointsConfig?.[endpoint ?? ''];
      if (endpointConfig?.models?.fetch) {
        try {
          await fetchUserModels.mutateAsync({ endpoint: endpoint });
        } catch (error) {
          console.warn('Failed to fetch models for endpoint:', endpoint, error);
        }
      }
    },
    [updateKey, keyName, fetchUserModels, endpoint, endpointsConfig],
  );

  return useMemo(
    () => ({ getExpiry, checkExpiry, saveUserKey }),
    [getExpiry, checkExpiry, saveUserKey],
  );
};

export default useUserKey;
