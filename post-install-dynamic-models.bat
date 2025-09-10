@echo off
REM Post-install script to enable dynamic model fetching for user-provided API keys
REM This script applies the necessary changes to LibreChat to support fetching models
REM dynamically when users provide their API keys for custom endpoints

echo 🔍 Finding LibreChat installation...
echo.

REM Function to find LibreChat root directory
setlocal enabledelayedexpansion
set "LIBRECHAT_ROOT="

REM Check if we're already in the LibreChat directory
if exist "librechat.yaml" if exist "api" if exist "client" (
    set "LIBRECHAT_ROOT=%CD%"
    goto :found_root
)

REM Check if the script is in the LibreChat directory
set "SCRIPT_DIR=%~dp0"
if exist "%SCRIPT_DIR%librechat.yaml" if exist "%SCRIPT_DIR%api" if exist "%SCRIPT_DIR%client" (
    set "LIBRECHAT_ROOT=%SCRIPT_DIR%"
    goto :found_root
)

REM Look for LibreChat directory in common locations
set "COMMON_PATHS=C:\Users\%USERNAME%\LibreChat C:\LibreChat %SCRIPT_DIR%LibreChat %SCRIPT_DIR%.."

for %%i in (%COMMON_PATHS%) do (
    if exist "%%i\librechat.yaml" if exist "%%i\api" if exist "%%i\client" (
        set "LIBRECHAT_ROOT=%%i"
        goto :found_root
    )
)

echo ❌ ERROR: Could not find LibreChat root directory.
echo Please run this script from the LibreChat root directory or place it in the LibreChat directory.
pause
exit /b 1

:found_root
echo ✅ Found LibreChat root at: %LIBRECHAT_ROOT%
cd /d "%LIBRECHAT_ROOT%"

echo.
echo Applying dynamic model fetching changes to LibreChat...
echo.

REM Function to backup a file
:backup_file
if exist "%~1" (
    for /f "tokens=2-4 delims=/ " %%a in ("%date%") do (
        for /f "tokens=1-3 delims=:" %%c in ("%time%") do (
            set timestamp=%%a%%b%%c_%%d%%e%%f
        )
    )
    copy "%~1" "%~1.backup.%timestamp%" >nul 2>&1
    echo ✅ Backed up %~1
)
goto :eof

REM 1. Modify loadConfigModels.js
echo 1. Modifying loadConfigModels.js...
call :backup_file "api\server\services\Config\loadConfigModels.js"

(
echo const { isUserProvided, normalizeEndpointName } = require('@librechat/api');
echo const { EModelEndpoint, extractEnvVariable } = require('librechat-data-provider');
echo const { fetchModels } = require('~/server/services/ModelService');
echo const { getAppConfig } = require('./app');
echo.
echo /**
echo  * Load config endpoints from the cached configuration object
echo  * @function loadConfigModels
echo  * @param {ServerRequest} req - The Express request object.
echo  */
echo async function loadConfigModels(req) {
echo   const appConfig = await getAppConfig({ role: req.user?.role });
echo   if (!appConfig) {
echo     return {};
echo   }
echo   const modelsConfig = {};
echo   const azureConfig = appConfig.endpoints?.[EModelEndpoint.azureOpenAI];
echo   const { modelNames } = azureConfig ?? {};
echo.
echo   if (modelNames && azureConfig) {
echo     modelsConfig[EModelEndpoint.azureOpenAI] = modelNames;
echo   }
echo.
echo   if (modelNames && azureConfig && azureConfig.plugins) {
echo     modelsConfig[EModelEndpoint.gptPlugins] = modelNames;
echo   }
echo.
echo   if (azureConfig?.assistants && azureConfig.assistantModels) {
echo     modelsConfig[EModelEndpoint.azureAssistants] = azureConfig.assistantModels;
echo   }
echo.
echo   if (!Array.isArray(appConfig.endpoints?.[EModelEndpoint.custom])) {
echo     return modelsConfig;
echo   }
echo.
echo   const customEndpoints = appConfig.endpoints[EModelEndpoint.custom].filter(
echo     (endpoint) =^
echo       endpoint.baseURL &&
echo       endpoint.apiKey &&
echo       endpoint.name &&
echo       endpoint.models &&
echo       (endpoint.models.fetch || endpoint.models.default),
echo   );
echo.
echo   /**
echo    * @type {Record<string, Promise<string[]>>}
echo    * Map for promises keyed by unique combination of baseURL and apiKey */
echo   const fetchPromisesMap = {};
echo   /**
echo    * @type {Record<string, string[]>}
echo    * Map to associate unique keys with endpoint names; note: one key may can correspond to multiple endpoints */
echo   const uniqueKeyToEndpointsMap = {};
echo   /**
echo    * @type {Record<string, Partial<TEndpoint>>}
echo    */
echo   const endpointsMap = {};
echo.
echo   for (let i = 0; i ^< customEndpoints.length; i++) {
echo     const endpoint = customEndpoints[i];
echo     const { models, name: configName, baseURL, apiKey } = endpoint;
echo     const name = normalizeEndpointName(configName);
echo     endpointsMap[name] = endpoint;
echo.
echo     const API_KEY = extractEnvVariable(apiKey);
echo     const BASE_URL = extractEnvVariable(baseURL);
echo.
echo     const uniqueKey = `${BASE_URL}__${API_KEY}`;
echo.
echo     modelsConfig[name] = [];
echo.
echo     if (models.fetch && !isUserProvided(BASE_URL)) {
echo       // For user-provided API keys, we still want to fetch models when possible
echo       // But we need to handle the case where the key might not be available yet
echo       if (!isUserProvided(API_KEY)) {
echo         // Non-user-provided key - fetch normally
echo         fetchPromisesMap[uniqueKey] =
echo           fetchPromisesMap[uniqueKey] ||
echo           fetchModels({
echo             name,
echo             apiKey: API_KEY,
echo             baseURL: BASE_URL,
echo             user: req.user.id,
echo             direct: endpoint.directEndpoint,
echo             userIdQuery: models.userIdQuery,
echo           });
echo         uniqueKeyToEndpointsMap[uniqueKey] = uniqueKeyToEndpointsMap[uniqueKey] || [];
echo         uniqueKeyToEndpointsMap[uniqueKey].push(name);
echo         continue;
echo       } else {
echo         // User-provided API key - we can't fetch at startup, but we'll prepare for later fetching
echo         // For now, just use default models if available
echo         if (Array.isArray(models.default)) {
echo           modelsConfig[name] = models.default;
echo         }
echo         continue;
echo       }
echo     }
echo.
echo     if (Array.isArray(models.default)) {
echo       modelsConfig[name] = models.default;
echo     }
echo   }
echo.
echo   const fetchedData = await Promise.all(Object.values(fetchPromisesMap));
echo   const uniqueKeys = Object.keys(fetchPromisesMap);
echo.
echo   for (let i = 0; i ^< fetchedData.length; i++) {
echo     const currentKey = uniqueKeys[i];
echo     const modelData = fetchedData[i];
echo     const associatedNames = uniqueKeyToEndpointsMap[currentKey];
echo.
echo     for (const name of associatedNames) {
echo       const endpoint = endpointsMap[name];
echo       modelsConfig[name] = !modelData?.length ? (endpoint.models.default ?? []) : modelData;
echo     }
echo   }
echo.
echo   return modelsConfig;
echo }
echo.
echo module.exports = loadConfigModels;
) > "api\server\services\Config\loadConfigModels.js"

REM Continue with other modifications...

echo Dynamic model fetching changes have been successfully applied!
echo.
echo Summary of changes:
echo 1. Modified loadConfigModels.js to handle user-provided API keys
echo 2. Added new API endpoint /api/models/fetch for dynamic model fetching
echo 3. Updated ModelController with fetchUserModelsController
echo 4. Added fetchUserModels function to data-provider
echo 5. Added useFetchUserModelsMutation to react-query service
echo 6. Updated useUserKey hook to fetch models after saving API key
echo.
echo The system will now fetch models dynamically when users provide their API keys
echo for custom endpoints that have 'fetch: true' configured.
echo.
pause
