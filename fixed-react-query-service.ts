import { QueryKeys } from '../keys';
import * as s from '../schemas';
import * as t from '../types';
import * as permissions from '../accessPermissions';
import { ResourceType } from '../accessPermissions';

export { hasPermissions } from '../accessPermissions';

export const useFetchUserModelsMutation = (): UseMutationResult<
  { endpoint: string; models: string[]; tokenConfig?: any },
  unknown,
  { endpoint: string },
  unknown
> => {
  const queryClient = useQueryClient();
  return useMutation((payload: { endpoint: string }) => dataService.fetchUserModels(payload), {
    onSuccess: (data, variables) => {
      console.log('[Dynamic Model Fetch] Updating React Query cache with models:', data.models.length);

      // Get the current models data
      const currentModelsData = queryClient.getQueryData<t.TModelsConfig>([QueryKeys.models]);

      // Update the models cache with the newly fetched models
      const updatedModelsData = {
        ...currentModelsData,
        [variables.endpoint]: data.models,
      };

      console.log('[Dynamic Model Fetch] Setting updated models cache for endpoint:', variables.endpoint);

      // Set the updated data
      queryClient.setQueryData([QueryKeys.models], updatedModelsData);

      // Also invalidate the models query to ensure UI updates
      queryClient.invalidateQueries([QueryKeys.models]);

      console.log('[Dynamic Model Fetch] Cache updated and invalidated successfully');
    },
  });
};

