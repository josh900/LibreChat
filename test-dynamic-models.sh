#!/bin/bash

# Test script for dynamic model fetching
echo "🧪 Testing Dynamic Model Fetching..."

# Check if containers are running
if ! docker compose ps | grep -q "LibreChat"; then
    echo "❌ LibreChat containers are not running"
    echo "Start them with: docker compose up -d"
    exit 1
fi

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

echo "✅ Containers are running (ID: $CONTAINER_ID)"

# Test 1: Check if API endpoint exists
echo ""
echo "🔍 Test 1: Checking API endpoints..."
API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3080/api/models 2>/dev/null || echo "000")

if [ "$API_RESPONSE" = "200" ]; then
    echo "✅ /api/models endpoint is accessible"
else
    echo "❌ /api/models endpoint not accessible (HTTP $API_RESPONSE)"
fi

# Test 2: Check if our new endpoint exists
FETCH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3080/api/models/fetch -H "Content-Type: application/json" -d '{"endpoint":"test"}' 2>/dev/null || echo "000")

if [ "$FETCH_RESPONSE" = "401" ]; then
    echo "✅ /api/models/fetch endpoint exists (401 = auth required, which is expected)"
elif [ "$FETCH_RESPONSE" = "200" ]; then
    echo "✅ /api/models/fetch endpoint exists and is accessible"
else
    echo "❌ /api/models/fetch endpoint not working (HTTP $FETCH_RESPONSE)"
fi

# Test 3: Check file contents in container
echo ""
echo "🔍 Test 3: Verifying files in container..."

if docker exec "$CONTAINER_ID" grep -q "fetchUserModelsController" "/app/api/server/controllers/ModelController.js" 2>/dev/null; then
    echo "✅ fetchUserModelsController function exists in container"
else
    echo "❌ fetchUserModelsController function missing from container"
fi

if docker exec "$CONTAINER_ID" grep -q "useAutoModelRefresh" "/app/client/src/routes/Root.tsx" 2>/dev/null; then
    echo "✅ useAutoModelRefresh hook integrated in container"
else
    echo "❌ useAutoModelRefresh hook not integrated in container"
fi

# Test 4: Check configuration
echo ""
echo "🔍 Test 4: Checking configuration..."

if [ -f "librechat.yaml" ] && grep -q "fetch: true" "librechat.yaml"; then
    echo "✅ librechat.yaml has dynamic model configuration"
else
    echo "❌ librechat.yaml missing or no 'fetch: true' configuration"
fi

echo ""
echo "📋 Manual Testing Steps:"
echo "1. Open LibreChat in browser"
echo "2. Go to model selection/settings"
echo "3. Enter your LiteLLM API key"
echo "4. Check browser developer console (F12) for debug messages"
echo "5. Check server logs: docker compose logs -f api | grep 'Dynamic'"
echo ""
echo "🔍 Expected debug messages:"
echo "- Browser console: '[Dynamic Model Fetch] Fetching models for endpoint: LiteLLM'"
echo "- Server logs: '[Dynamic Model Fetch] Controller called with endpoint: LiteLLM'"
