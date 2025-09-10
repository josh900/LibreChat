#!/bin/bash

# Post-install script to enable dynamic model fetching for user-provided API keys
# This script modifies running Docker containers to add dynamic model fetching functionality

set -e

echo "🚀 Dynamic Model Fetching Post-Install Script"
echo "=============================================="

# Function to find LibreChat root directory
find_librechat_root() {
    local current_dir="$(pwd)"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Check if we're already in the LibreChat directory
    if [ -f "librechat.yaml" ] && [ -f "docker-compose.yml" ]; then
        echo "$current_dir"
        return 0
    fi

    # Check if the script is in the LibreChat directory
    if [ -f "$script_dir/librechat.yaml" ] && [ -f "$script_dir/docker-compose.yml" ]; then
        echo "$script_dir"
        return 0
    fi

    # Look for LibreChat directory in common locations
    local common_paths=(
        "/home/ubuntu/LibreChat"
        "/root/LibreChat"
        "/opt/LibreChat"
        "$(dirname "$script_dir")/LibreChat"
        "$(dirname "$script_dir")"
    )

    for path in "${common_paths[@]}"; do
        if [ -f "$path/librechat.yaml" ] && [ -f "$path/docker-compose.yml" ]; then
            echo "$path"
            return 0
        fi
    done

    echo "ERROR: Could not find LibreChat root directory. Please run this script from the LibreChat root directory." >&2
    return 1
}

# Find LibreChat root
LIBRECHAT_ROOT=$(find_librechat_root)
if [ $? -ne 0 ]; then
    exit 1
fi

echo "✅ Found LibreChat root at: $LIBRECHAT_ROOT"
cd "$LIBRECHAT_ROOT"

# Check if containers are running
echo ""
echo "🔍 Checking Docker containers..."
if ! docker compose ps | grep -q "LibreChat"; then
    echo "❌ LibreChat containers are not running"
    echo "Please start the containers first with: docker compose up -d"
    exit 1
fi

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')
echo "✅ LibreChat container is running (ID: $CONTAINER_ID)"

# Create the modified source files
echo ""
echo "📝 Creating modified source files..."

# Create modified loadConfigModels.js
echo "1. Creating loadConfigModels.js..."
cat > api/server/services/Config/loadConfigModels.js << 'EOF'
const { isUserProvided, normalizeEndpointName } = require('@librechat/api');
const { EModelEndpoint, extractEnvVariable } = require('librechat-data-provider');
const { fetchModels } = require('~/server/services/ModelService');
const { getAppConfig } = require('./app');

console.log('[Dynamic Model Fetch] loadConfigModels.js loaded');

/**
 * Load config endpoints from the cached configuration object
 * @function loadConfigModels
 * @param {ServerRequest} req - The Express request object.
 */
async function loadConfigModels(req) {
  const appConfig = await getAppConfig({ role: req.user?.role });
  if (!appConfig) {
    return {};
  }
  const modelsConfig = {};
  const azureConfig = appConfig.endpoints?.[EModelEndpoint.azureOpenAI];
  const { modelNames } = azureConfig ?? {};

  if (modelNames && azureConfig) {
    modelsConfig[EModelEndpoint.azureOpenAI] = modelNames;
  }

  if (modelNames && azureConfig && azureConfig.plugins) {
    modelsConfig[EModelEndpoint.gptPlugins] = modelNames;
  }

  if (azureConfig?.assistants && azureConfig.assistantModels) {
    modelsConfig[EModelEndpoint.azureAssistants] = azureConfig.assistantModels;
  }

  if (!Array.isArray(appConfig.endpoints?.[EModelEndpoint.custom])) {
    return modelsConfig;
  }

  const customEndpoints = appConfig.endpoints[EModelEndpoint.custom].filter(
    (endpoint) =>
      endpoint.baseURL &&
      endpoint.apiKey &&
      endpoint.name &&
      endpoint.models &&
      (endpoint.models.fetch || endpoint.models.default),
  );

  /**
   * @type {Record<string, Promise<string[]>>}
   * Map for promises keyed by unique combination of baseURL and apiKey */
  const fetchPromisesMap = {};
  /**
   * @type {Record<string, string[]>}
   * Map to associate unique keys with endpoint names; note: one key may can correspond to multiple endpoints */
  const uniqueKeyToEndpointsMap = {};
  /**
   * @type {Record<string, Partial<TEndpoint>>}
   * Map to associate endpoint names to their configurations */
  const endpointsMap = {};

  for (let i = 0; i < customEndpoints.length; i++) {
    const endpoint = customEndpoints[i];
    const { models, name: configName, baseURL, apiKey } = endpoint;
    const name = normalizeEndpointName(configName);
    endpointsMap[name] = endpoint;

    const API_KEY = extractEnvVariable(apiKey);
    const BASE_URL = extractEnvVariable(baseURL);

    const uniqueKey = `${BASE_URL}__${API_KEY}`;

    modelsConfig[name] = [];

    if (models.fetch && !isUserProvided(BASE_URL)) {
      // For user-provided API keys, we still want to fetch models when possible
      // But we need to handle the case where the key might not be available yet
      if (!isUserProvided(API_KEY)) {
        // Non-user-provided key - fetch normally
        fetchPromisesMap[uniqueKey] =
          fetchPromisesMap[uniqueKey] ||
          fetchModels({
            name,
            apiKey: API_KEY,
            baseURL: BASE_URL,
            user: req.user.id,
            direct: endpoint.directEndpoint,
            userIdQuery: models.userIdQuery,
          });
        uniqueKeyToEndpointsMap[uniqueKey] = uniqueKeyToEndpointsMap[uniqueKey] || [];
        uniqueKeyToEndpointsMap[uniqueKey].push(name);
        continue;
      } else {
        // User-provided API key - we can't fetch at startup, but we'll prepare for later fetching
        // For now, just use default models if available
        if (Array.isArray(models.default)) {
          modelsConfig[name] = models.default;
        }
        continue;
      }
    }

    if (Array.isArray(models.default)) {
      modelsConfig[name] = models.default;
    }
  }

  const fetchedData = await Promise.all(Object.values(fetchPromisesMap));
  const uniqueKeys = Object.keys(fetchPromisesMap);

  for (let i = 0; i < fetchedData.length; i++) {
    const currentKey = uniqueKeys[i];
    const modelData = fetchedData[i];
    const associatedNames = uniqueKeyToEndpointsMap[currentKey];

    for (const name of associatedNames) {
      const endpoint = endpointsMap[name];
      modelsConfig[name] = !modelData?.length ? (endpoint.models.default ?? []) : modelData;
    }
  }

  return modelsConfig;
}

module.exports = loadConfigModels;
EOF

# Create modified models.js route
echo "2. Creating models.js route..."
cat > api/server/routes/models.js << 'EOF'
const express = require('express');
const { modelController, fetchUserModelsController } = require('~/server/controllers/ModelController');
const { requireJwtAuth } = require('~/server/middleware/');

const router = express.Router();
router.get('/', requireJwtAuth, modelController);
router.post('/fetch', requireJwtAuth, fetchUserModelsController);

module.exports = router;
EOF

# Create modified ModelController.js
echo "3. Creating ModelController.js..."
cat > api/server/controllers/ModelController.js << 'EOF'
const { CacheKeys } = require('librechat-data-provider');
const { loadDefaultModels, loadConfigModels } = require('~/server/services/Config');
const { getLogStores } = require('~/cache');
const { logger } = require('~/config');
const { fetchModels } = require('~/server/services/ModelService');
const { getUserKeyValues } = require('~/server/services/UserService');
const { getCustomEndpointConfig } = require('@librechat/api');

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

    // Get the endpoint configuration
    const endpointConfig = getCustomEndpointConfig({
      endpoint: endpointName,
      appConfig: req.config,
    });

    if (!endpointConfig) {
      return res.status(404).send({ error: `Endpoint ${endpointName} not found` });
    }

    // Check if this endpoint supports model fetching
    if (!endpointConfig.models?.fetch) {
      return res.status(400).send({ error: `Endpoint ${endpointName} does not support model fetching` });
    }

    // Get user-provided keys
    const userValues = await getUserKeyValues({
      userId: req.user.id,
      name: endpointName
    });

    const apiKey = userValues?.apiKey;
    const baseURL = userValues?.baseURL || endpointConfig.baseURL;

    if (!apiKey) {
      return res.status(400).send({ error: 'API key not provided for this endpoint' });
    }

    if (!baseURL) {
      return res.status(400).send({ error: 'Base URL not available for this endpoint' });
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
      direct: endpointConfig.directEndpoint,
      userIdQuery: endpointConfig.models.userIdQuery,
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
EOF

# Create modified data-service.ts
echo "4. Creating data-service.ts..."
cat >> packages/data-provider/src/data-service.ts << 'EOF'

export const fetchUserModels = async (payload: { endpoint: string }): Promise<{ endpoint: string; models: string[]; tokenConfig?: any }> => {
  return request.post(endpoints.fetchUserModels(), payload);
};
EOF

# Create modified react-query-service.ts
echo "5. Creating react-query-service.ts..."
cat >> packages/data-provider/src/react-query/react-query-service.ts << 'EOF'

export const useFetchUserModelsMutation = (): UseMutationResult<
  { endpoint: string; models: string[]; tokenConfig?: any },
  unknown,
  { endpoint: string },
  unknown
> => {
  const queryClient = useQueryClient();
  return useMutation((payload: { endpoint: string }) => dataService.fetchUserModels(payload), {
    onSuccess: (data, variables) => {
      // Update the models cache with the newly fetched models
      queryClient.setQueryData([QueryKeys.models], (oldData: t.TModelsConfig | undefined) => {
        if (!oldData) {
          return oldData;
        }
        return {
          ...oldData,
          [variables.endpoint]: data.models,
        };
      });
    },
  });
};
EOF

# Create modified useUserKey.ts
echo "6. Creating useUserKey.ts..."
cat > client/src/hooks/Input/useUserKey.ts << 'EOF'
import { useMemo, useCallback } from 'react';
import { EModelEndpoint } from 'librechat-data-provider';
import { useUserKeyQuery, useUpdateUserKeysMutation, useFetchUserModelsMutation } from 'librechat-data-provider/react-query';
import { useGetEndpointsQuery } from '~/data-provider';

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
          console.log(`[Dynamic Model Fetch] Fetching models for endpoint: ${endpoint}`);
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
EOF

# Create auto-refresh hook
echo "7. Creating useAutoModelRefresh.ts..."
cat > client/src/hooks/Input/useAutoModelRefresh.ts << 'EOF'
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
        config?.userProvide &&
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
EOF

# Update Root.tsx
echo "8. Updating Root.tsx..."
# Add import for useAutoModelRefresh if not already present
if ! grep -q "useAutoModelRefresh" "client/src/routes/Root.tsx"; then
  sed -i "/import { useAuthContext }/a import useAutoModelRefresh from '~/hooks/Input/useAutoModelRefresh';" "client/src/routes/Root.tsx"
fi

# Add hook usage if not already present
if ! grep -q "useAutoModelRefresh()" "client/src/routes/Root.tsx"; then
  sed -i "/useHealthCheck(isAuthenticated);/a \
  // Auto-refresh models for user-provided endpoints\
  useAutoModelRefresh();" "client/src/routes/Root.tsx"
fi

# Create docker-compose override to mount the files
echo ""
echo "🔧 Creating Docker volume mounts..."

cat > docker-compose.override.yml << 'EOF'
# Mount our modified source files into the running container
services:
  api:
    volumes:
      - type: bind
        source: ./api/server/services/Config/loadConfigModels.js
        target: /app/api/server/services/Config/loadConfigModels.js
      - type: bind
        source: ./api/server/controllers/ModelController.js
        target: /app/api/server/controllers/ModelController.js
      - type: bind
        source: ./api/server/routes/models.js
        target: /app/api/server/routes/models.js
      - type: bind
        source: ./packages/data-provider/src/data-service.ts
        target: /app/packages/data-provider/src/data-service.ts
      - type: bind
        source: ./packages/data-provider/src/react-query/react-query-service.ts
        target: /app/packages/data-provider/src/react-query/react-query-service.ts
      - type: bind
        source: ./client/src/hooks/Input/useUserKey.ts
        target: /app/client/src/hooks/Input/useUserKey.ts
      - type: bind
        source: ./client/src/routes/Root.tsx
        target: /app/client/src/routes/Root.tsx
      - type: bind
        source: ./client/src/hooks/Input/useAutoModelRefresh.ts
        target: /app/client/src/hooks/Input/useAutoModelRefresh.ts
      - type: bind
        source: ./librechat.yaml
        target: /app/librechat.yaml
EOF

echo "✅ Created docker-compose.override.yml with volume mounts"

# Restart containers to apply changes
echo ""
echo "🔄 Restarting containers to apply changes..."
docker compose down
docker compose up -d

# Wait for startup
echo ""
echo "⏳ Waiting for containers to start..."
sleep 15

# Test the setup
CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

echo ""
echo "🧪 Testing the setup..."
echo "Container ID: $CONTAINER_ID"

# Test API endpoints
echo ""
echo "🔍 Testing API endpoints..."

# Test models endpoint
MODELS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3080/api/models 2>/dev/null || echo "000")
echo "Models endpoint: HTTP $MODELS_RESPONSE"

# Test fetch endpoint
FETCH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3080/api/models/fetch -H "Content-Type: application/json" -d '{"endpoint":"test"}' 2>/dev/null || echo "000")
echo "Fetch endpoint: HTTP $FETCH_RESPONSE"

# Check if files are mounted
echo ""
echo "🔍 Checking if files are mounted in container..."

if docker exec "$CONTAINER_ID" grep -q "fetchUserModelsController" "/app/api/server/controllers/ModelController.js" 2>/dev/null; then
    echo "✅ fetchUserModelsController found in container"
else
    echo "❌ fetchUserModelsController not found in container"
fi

if docker exec "$CONTAINER_ID" grep -q "useAutoModelRefresh" "/app/client/src/routes/Root.tsx" 2>/dev/null; then
    echo "✅ useAutoModelRefresh integrated in container"
else
    echo "❌ useAutoModelRefresh not integrated in container"
fi

echo ""
echo "🎉 Dynamic Model Fetching Setup Complete!"
echo ""
echo "📋 Next steps:"
echo "1. Open LibreChat at http://your-server:3080"
echo "2. Go to Settings/Model Selection"
echo "3. Enter your LiteLLM API key"
echo "4. Check browser console (F12) for debug messages:"
echo "   - '[Dynamic Model Fetch] Fetching models for endpoint: LiteLLM'"
echo "5. Check server logs: docker compose logs -f api | grep 'Dynamic'"
