const { CacheKeys } = require('librechat-data-provider');
const { loadDefaultModels, loadConfigModels } = require('~/server/services/Config');
const { getLogStores } = require('~/cache');
const { logger } = require('~/config');
const { fetchModels } = require('~/server/services/ModelService');
const { getUserKeyValues } = require('~/server/services/UserService');

/**
 * @param {ServerRequest} req
 * @returns {Promise<TModelsConfig>} The models config.
 */
const getModelsConfig = async (req) => {
  const cache = getLogStores(CacheKeys.CONFIG_STORE);
  let modelsConfig = await cache.get(CacheKeys.MODELS_CONFIG);
  if (!modelsConfig) {
    modelsConfig = await loadModels(req);
  }

  return modelsConfig;
};

/**
 * Loads the models from the config.
 * @param {ServerRequest} req - The Express request object.
 * @returns {Promise<TModelsConfig>} The models config.
 */
async function loadModels(req) {
  const cache = getLogStores(CacheKeys.CONFIG_STORE);
  const cachedModelsConfig = await cache.get(CacheKeys.MODELS_CONFIG);
  if (cachedModelsConfig) {
    return cachedModelsConfig;
  }
  const defaultModelsConfig = await loadDefaultModels(req);
  const customModelsConfig = await loadConfigModels(req);

  const modelConfig = { ...defaultModelsConfig, ...customModelsConfig };

  await cache.set(CacheKeys.MODELS_CONFIG, modelConfig);
  return modelConfig;
}

async function modelController(req, res) {
  try {
    const modelConfig = await loadModels(req);
    res.send(modelConfig);
  } catch (error) {
    logger.error('Error fetching models:', error);
    res.status(500).send({ error: error.message });
  }
}

/**
 * Fetches models dynamically for user-provided API keys
 * @param {ServerRequest} req - The Express request object
 * @param {ServerResponse} res - The Express response object
 */
async function fetchUserModelsController(req, res) {
  console.log('[Dynamic Model Fetch] Controller called with endpoint:', req.body?.endpoint);

  try {
    const { endpoint: endpointName } = req.body;

    if (!endpointName) {
      return res.status(400).send({ error: 'Endpoint name is required' });
    }

    // For now, we'll hardcode support for LiteLLM endpoint
    // In the future, this could be extended to support other endpoints
    if (endpointName !== 'LiteLLM') {
      return res.status(400).send({ error: `Endpoint ${endpointName} does not support dynamic model fetching` });
    }

    // Get user-provided keys
    const userValues = await getUserKeyValues({
      userId: req.user.id,
      name: endpointName
    });

    const apiKey = userValues?.apiKey;
    
    // Use the hardcoded LiteLLM baseURL since we know it from librechat.yaml
    const baseURL = 'https://litellm.skoop.digital/v1';

    if (!apiKey) {
      console.log('[Dynamic Model Fetch] No API key found for user:', req.user.id);
      return res.status(400).send({ error: 'API key not provided for this endpoint' });
    }

    console.log(`[Dynamic Model Fetch] Fetching models for user ${req.user.id} from ${baseURL}`);

    // Create user-specific cache key
    const cache = getLogStores(CacheKeys.TOKEN_CONFIG);
    const tokenKey = `${endpointName}:${req.user.id}`;

    // Fetch models
    const models = await fetchModels({
      apiKey,
      baseURL,
      name: endpointName,
      user: req.user.id,
      tokenKey,
      direct: false, // LiteLLM doesn't need direct mode
      userIdQuery: false
    });

    console.log(`[Dynamic Model Fetch] Successfully fetched ${models.length} models for endpoint ${endpointName}`);

    // Cache the token config
    const endpointTokenConfig = await cache.get(tokenKey);

    // Return the fetched models
    res.send({
      endpoint: endpointName,
      models,
      tokenConfig: endpointTokenConfig,
    });

  } catch (error) {
    console.error('[Dynamic Model Fetch] Error fetching user models:', error);
    logger.error('Error fetching user models:', error);
    res.status(500).send({ error: error.message });
  }
}

module.exports = { modelController, loadModels, getModelsConfig, fetchUserModelsController };

