#!/bin/bash

# Complete setup script for dynamic model fetching
# This script applies all changes and ensures proper Docker rebuild

set -e

echo "🚀 Complete Dynamic Model Fetching Setup"
echo "=========================================="

# Check if we're in the right directory
if [ ! -f "librechat.yaml" ] || [ ! -d "api" ] || [ ! -d "client" ]; then
    echo "❌ Please run this script from the LibreChat root directory"
    exit 1
fi

echo "✅ Running from LibreChat root directory"

# Step 1: Apply source code changes
echo ""
echo "📝 Step 1: Applying source code changes..."
./post-install-dynamic-models.sh

# Step 2: Verify changes are applied
echo ""
echo "🔍 Step 2: Verifying changes..."
if ! grep -q "fetchUserModelsController" "api/server/controllers/ModelController.js"; then
    echo "❌ ModelController changes not applied correctly"
    exit 1
fi

if ! grep -q "useAutoModelRefresh" "client/src/routes/Root.tsx"; then
    echo "❌ Root component changes not applied correctly"
    exit 1
fi

echo "✅ All changes applied successfully"

# Step 3: Add debugging logs to key files
echo ""
echo "🐛 Step 3: Adding debug logging..."

# Add logging to ModelController
if ! grep -q "console.log.*Dynamic model fetch" "api/server/controllers/ModelController.js"; then
    sed -i '/async function fetchUserModelsController/a \
  console.log("[Dynamic Model Fetch] Controller called with endpoint:", endpointName);' "api/server/controllers/ModelController.js"
    echo "✅ Added debug logging to ModelController"
fi

# Add logging to useUserKey hook
if ! grep -q "console.log.*Dynamic model fetch" "client/src/hooks/Input/useUserKey.ts"; then
    sed -i '/await fetchUserModels.mutateAsync/a \
        console.log("[Dynamic Model Fetch] Fetching models for endpoint:", endpoint);' "client/src/hooks/Input/useUserKey.ts"
    echo "✅ Added debug logging to useUserKey hook"
fi

# Step 4: Stop containers
echo ""
echo "🛑 Step 4: Stopping containers..."
docker compose down

# Step 5: Rebuild containers from scratch
echo ""
echo "🔨 Step 5: Rebuilding containers..."
docker compose build --no-cache

# Step 6: Start containers
echo ""
echo "▶️  Step 6: Starting containers..."
docker compose up -d

# Step 7: Wait for startup and check logs
echo ""
echo "⏳ Step 7: Waiting for startup..."
sleep 10

echo "📋 Checking container status..."
docker compose ps

echo ""
echo "🔍 Checking for any startup errors..."
docker compose logs --tail=20 api | grep -i error || echo "✅ No errors found in recent logs"

# Step 8: Create/update configuration
echo ""
echo "⚙️  Step 8: Configuration check..."

if [ ! -f "librechat.yaml" ]; then
    echo "❌ librechat.yaml not found"
    exit 1
fi

# Check if dynamic model configuration exists
if ! grep -q "fetch: true" "librechat.yaml"; then
    echo "⚠️  No endpoints with 'fetch: true' found in librechat.yaml"
    echo ""
    echo "📝 Please add this to your librechat.yaml:"
    echo ""
    echo "endpoints:"
    echo "  custom:"
    echo "    - name: \"LiteLLM\""
    echo "      apiKey: \"user_provided\""
    echo "      baseURL: \"https://your-litellm-server.com/v1\""
    echo "      models:"
    echo "        default: [\"gemini/gemini-2.0-flash-lite\"]"
    echo "        fetch: true"
    echo ""
    echo "Then restart the containers:"
    echo "docker compose restart"
else
    echo "✅ Dynamic model configuration found in librechat.yaml"
fi

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 To test the functionality:"
echo "1. Open LibreChat in your browser"
echo "2. Go to Settings and enter your LiteLLM API key"
echo "3. Check browser console (F12) for debug messages"
echo "4. Check server logs: docker compose logs -f api"
echo ""
echo "🔍 Debug logs will show:"
echo "- '[Dynamic Model Fetch] Controller called' - API endpoint hit"
echo "- '[Dynamic Model Fetch] Fetching models' - Client-side fetch triggered"
echo ""
echo "If you don't see these logs, the feature isn't working properly."
