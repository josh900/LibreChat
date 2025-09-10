@echo off
REM Diagnostic script to check LibreChat installation and file structure
echo 🔍 Diagnosing LibreChat installation...
echo.

REM Check current directory
echo 📂 Current directory: %CD%
echo.

REM Check for LibreChat files
echo 🔍 Checking for LibreChat files:
set "missing_files="
if exist "librechat.yaml" (
    echo ✅ librechat.yaml found
) else (
    echo ❌ librechat.yaml missing
    set "missing_files=1"
)

if exist "package.json" (
    echo ✅ package.json found
) else (
    echo ❌ package.json missing
    set "missing_files=1"
)

if exist "docker-compose.yml" (
    echo ✅ docker-compose.yml found
) else (
    echo ❌ docker-compose.yml missing
    set "missing_files=1"
)
echo.

REM Check for directories
echo 🔍 Checking for LibreChat directories:
set "missing_dirs="
if exist "api" (
    echo ✅ api/ directory found
) else (
    echo ❌ api/ directory missing
    set "missing_dirs=1"
)

if exist "client" (
    echo ✅ client/ directory found
) else (
    echo ❌ client/ directory missing
    set "missing_dirs=1"
)

if exist "packages" (
    echo ✅ packages/ directory found
) else (
    echo ❌ packages/ directory missing
    set "missing_dirs=1"
)
echo.

REM Check for specific files needed by the post-install script
echo 🔍 Checking for files needed by post-install script:
set "missing_critical="
if exist "api\server\services\Config\loadConfigModels.js" (
    echo ✅ api/server/services/Config/loadConfigModels.js found
) else (
    echo ❌ api/server/services/Config/loadConfigModels.js missing
    set "missing_critical=1"
)

if exist "api\server\routes\models.js" (
    echo ✅ api/server/routes/models.js found
) else (
    echo ❌ api/server/routes/models.js missing
    set "missing_critical=1"
)

if exist "api\server\controllers\ModelController.js" (
    echo ✅ api/server/controllers/ModelController.js found
) else (
    echo ❌ api/server/controllers/ModelController.js missing
    set "missing_critical=1"
)

if exist "packages\data-provider\src\api-endpoints.ts" (
    echo ✅ packages/data-provider/src/api-endpoints.ts found
) else (
    echo ❌ packages/data-provider/src/api-endpoints.ts missing
    set "missing_critical=1"
)

if exist "packages\data-provider\src\data-service.ts" (
    echo ✅ packages/data-provider/src/data-service.ts found
) else (
    echo ❌ packages/data-provider/src/data-service.ts missing
    set "missing_critical=1"
)

if exist "packages\data-provider\src\react-query\react-query-service.ts" (
    echo ✅ packages/data-provider/src/react-query/react-query-service.ts found
) else (
    echo ❌ packages/data-provider/src/react-query/react-query-service.ts missing
    set "missing_critical=1"
)

if exist "client\src\hooks\Input\useUserKey.ts" (
    echo ✅ client/src/hooks/Input/useUserKey.ts found
) else (
    echo ❌ client/src/hooks/Input/useUserKey.ts missing
    set "missing_critical=1"
)

if exist "client\src\routes\Root.tsx" (
    echo ✅ client/src/routes/Root.tsx found
) else (
    echo ❌ client/src/routes/Root.tsx missing
    set "missing_critical=1"
)
echo.

REM Summary
if "%missing_files%"=="" if "%missing_dirs%"=="" if "%missing_critical%"=="" (
    echo 🎉 LibreChat installation appears to be complete and ready for post-install script!
    echo.
    echo 🚀 You can now run:
    echo    post-install-dynamic-models.bat
) else (
    echo ⚠️ Issues found:
    if defined missing_files (
        echo    Some basic LibreChat files are missing
    )
    if defined missing_dirs (
        echo    Some required directories are missing
    )
    if defined missing_critical (
        echo    Critical files needed by the post-install script are missing
        echo.
        echo ❌ Post-install script will likely fail due to missing files.
        echo    Please ensure you're running this from the correct LibreChat directory.
    )
)

echo.
echo 💡 If you're having issues, make sure you're running this script from the LibreChat root directory.
echo.
pause
