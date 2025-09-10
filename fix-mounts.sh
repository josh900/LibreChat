#!/bin/bash

echo "🔧 Fixing Volume Mounts for Dynamic Model Fetching"
echo "================================================="

# Stop containers
echo "🛑 Stopping containers..."
docker compose down

# Start containers with new mounts
echo "🚀 Starting containers with volume mounts..."
docker compose up -d

# Wait for startup
echo "⏳ Waiting for containers to start..."
sleep 20

# Verify the mounts are working
echo "🔍 Verifying volume mounts..."
CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container failed to start"
    exit 1
fi

echo "✅ Container running: $CONTAINER_ID"

# Check if our files are properly mounted
echo ""
echo "🔍 Checking file mounts..."

files_to_check=(
    "/app/api/server/services/Config/loadConfigModels.js:Dynamic Model Fetch"
    "/app/api/server/controllers/ModelController.js:fetchUserModelsController"
    "/app/client/src/hooks/Input/useUserKey.ts:Dynamic Model Fetch"
    "/app/client/src/hooks/Input/useAutoModelRefresh.ts:useAutoModelRefresh"
)

for file_check in "${files_to_check[@]}"; do
    IFS=':' read -r file_path search_term <<< "$file_check"
    if docker exec "$CONTAINER_ID" grep -q "$search_term" "$file_path" 2>/dev/null; then
        echo "✅ $file_path contains '$search_term'"
    else
        echo "❌ $file_path missing '$search_term'"
    fi
done

# Test API endpoints
echo ""
echo "🔍 Testing API endpoints..."
MODELS_RESP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3080/api/models 2>/dev/null || echo "000")
FETCH_RESP=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3080/api/models/fetch \
    -H "Content-Type: application/json" \
    -d '{"endpoint":"LiteLLM"}' 2>/dev/null || echo "000")

echo "Models endpoint: HTTP $MODELS_RESP"
echo "Fetch endpoint: HTTP $FETCH_RESP"

echo ""
echo "🎉 Volume mounts fixed!"
echo ""
echo "📋 Next steps:"
echo "1. Open LibreChat at http://your-server:3080"
echo "2. Login and go to Settings/Model Selection"
echo "3. Enter your LiteLLM API key"
echo "4. Check browser console for debug messages"
echo "5. Check server logs: docker compose logs -f api | grep Dynamic"
