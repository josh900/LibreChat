#!/bin/bash

# Final test script for dynamic model fetching
echo "🎯 Final Dynamic Model Fetching Test"
echo "==================================="

# Check if containers are running
if ! docker compose ps | grep -q "LibreChat"; then
    echo "❌ LibreChat containers are not running"
    echo "Please run: docker compose up -d"
    exit 1
fi

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')
echo "✅ LibreChat container is running (ID: $CONTAINER_ID)"

# Test 1: Check if our files are mounted correctly
echo ""
echo "🔍 Test 1: Verifying file mounts..."

files_to_check=(
    "/app/api/server/services/Config/loadConfigModels.js"
    "/app/api/server/controllers/ModelController.js"
    "/app/api/server/routes/models.js"
    "/app/client/src/hooks/Input/useUserKey.ts"
    "/app/client/src/routes/Root.tsx"
    "/app/client/src/hooks/Input/useAutoModelRefresh.ts"
)

for file in "${files_to_check[@]}"; do
    if docker exec "$CONTAINER_ID" test -f "$file" 2>/dev/null; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
    fi
done

# Test 2: Check if our code is in the mounted files
echo ""
echo "🔍 Test 2: Checking code content..."

if docker exec "$CONTAINER_ID" grep -q "fetchUserModelsController" "/app/api/server/controllers/ModelController.js" 2>/dev/null; then
    echo "✅ fetchUserModelsController function found"
else
    echo "❌ fetchUserModelsController function missing"
fi

if docker exec "$CONTAINER_ID" grep -q "\[Dynamic Model Fetch\]" "/app/api/server/controllers/ModelController.js" 2>/dev/null; then
    echo "✅ Debug logging found in ModelController"
else
    echo "❌ Debug logging missing in ModelController"
fi

if docker exec "$CONTAINER_ID" grep -q "useAutoModelRefresh" "/app/client/src/routes/Root.tsx" 2>/dev/null; then
    echo "✅ useAutoModelRefresh integrated in Root"
else
    echo "❌ useAutoModelRefresh not integrated in Root"
fi

# Test 3: Test API endpoints
echo ""
echo "🔍 Test 3: Testing API endpoints..."

# Test models endpoint (should return 401 without auth)
MODELS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3080/api/models 2>/dev/null || echo "000")
echo "Models endpoint: HTTP $MODELS_RESPONSE"

# Test fetch endpoint (should return 401 without auth)
FETCH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3080/api/models/fetch \
  -H "Content-Type: application/json" \
  -d '{"endpoint":"LiteLLM"}' 2>/dev/null || echo "000")
echo "Fetch endpoint: HTTP $FETCH_RESPONSE"

# Test 4: Check librechat.yaml configuration
echo ""
echo "🔍 Test 4: Checking configuration..."

if grep -q "fetch: true" "librechat.yaml" 2>/dev/null; then
    echo "✅ librechat.yaml has fetch: true configuration"
else
    echo "⚠️  librechat.yaml missing fetch: true configuration"
    echo "   Add this to your custom endpoint:"
    echo "   models:"
    echo "     fetch: true"
fi

# Test 5: Check server logs for our debug messages
echo ""
echo "🔍 Test 5: Checking server logs..."

echo "Recent server logs:"
docker compose logs --tail=10 api 2>/dev/null | grep -E "(Dynamic|error|Error)" || echo "No relevant logs found"

echo ""
echo "🎉 Test Complete!"
echo ""
echo "📋 Expected Results:"
echo "✅ All files should exist and contain our code"
echo "✅ API endpoints should return HTTP 401 (authentication required)"
echo "✅ librechat.yaml should have fetch: true"
echo ""
echo "🚀 Ready to test!"
echo ""
echo "📋 To test in browser:"
echo "1. Open http://your-server:3080"
echo "2. Login and go to Settings/Model Selection"
echo "3. Enter your LiteLLM API key"
echo "4. Check browser console (F12) for:"
echo "   '[Dynamic Model Fetch] Fetching models for endpoint: LiteLLM'"
echo "5. Check server logs:"
echo "   docker compose logs -f api | grep 'Dynamic'"
