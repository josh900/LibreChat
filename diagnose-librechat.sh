#!/bin/bash

# Diagnostic script to check LibreChat installation and file structure
echo "🔍 Diagnosing LibreChat installation..."
echo

# Check current directory
echo "📂 Current directory: $(pwd)"
echo

# Check for LibreChat files
echo "🔍 Checking for LibreChat files:"
check_files=("librechat.yaml" "package.json" "docker-compose.yml")
missing_files=()

for file in "${check_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file found"
    else
        echo "❌ $file missing"
        missing_files+=("$file")
    fi
done
echo

# Check for directories
echo "🔍 Checking for LibreChat directories:"
check_dirs=("api" "client" "packages")
missing_dirs=()

for dir in "${check_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir/ directory found"
    else
        echo "❌ $dir/ directory missing"
        missing_dirs+=("$dir")
    fi
done
echo

# Check for specific files needed by the post-install script
echo "🔍 Checking for files needed by post-install script:"
critical_files=(
    "api/server/services/Config/loadConfigModels.js"
    "api/server/routes/models.js"
    "api/server/controllers/ModelController.js"
    "packages/data-provider/src/api-endpoints.ts"
    "packages/data-provider/src/data-service.ts"
    "packages/data-provider/src/react-query/react-query-service.ts"
    "client/src/hooks/Input/useUserKey.ts"
    "client/src/routes/Root.tsx"
)

missing_critical=()
for file in "${critical_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file found"
    else
        echo "❌ $file missing"
        missing_critical+=("$file")
    fi
done
echo

# Summary
if [ ${#missing_files[@]} -eq 0 ] && [ ${#missing_dirs[@]} -eq 0 ] && [ ${#missing_critical[@]} -eq 0 ]; then
    echo "🎉 LibreChat installation appears to be complete and ready for post-install script!"
    echo
    echo "🚀 You can now run:"
    echo "   ./post-install-dynamic-models.sh"
else
    echo "⚠️  Issues found:"
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo "   Missing files: ${missing_files[*]}"
    fi
    if [ ${#missing_dirs[@]} -gt 0 ]; then
        echo "   Missing directories: ${missing_dirs[*]}"
    fi
    if [ ${#missing_critical[@]} -gt 0 ]; then
        echo "   Missing critical files: ${missing_critical[*]}"
        echo
        echo "❌ Post-install script will likely fail due to missing files."
        echo "   Please ensure you're running this from the correct LibreChat directory."
    fi
fi

echo
echo "💡 If you're having issues, make sure you're running this script from the LibreChat root directory."
