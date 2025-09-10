// Clean version of data-service.ts with single fetchUserModels function
export const fetchUserModels = async (payload: { endpoint: string }): Promise<{ endpoint: string; models: string[]; tokenConfig?: any }> => {
  return request.post(endpoints.fetchUserModels(), payload);
};
