#!/bin/bash

# Fix Docker setup for dynamic model fetching
echo "🔧 Fixing Docker setup for dynamic model fetching..."

# Check if we're in the right directory
if [ ! -f "librechat.yaml" ] || [ ! -d "api" ] || [ ! -d "client" ]; then
    echo "❌ Please run this script from the LibreChat root directory"
    exit 1
fi

echo "✅ Running from LibreChat root directory"

# Stop containers
echo ""
echo "🛑 Stopping containers..."
docker compose down

# Create a simpler docker-compose override that just mounts the key files
cat > docker-compose.override.yml << 'EOF'
# Simple override to mount our modified source files
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
        source: ./packages/data-provider/src/api-endpoints.ts
        target: /app/packages/data-provider/src/api-endpoints.ts
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

echo "✅ Created docker-compose.override.yml with file mounts"

# Rebuild and restart
echo ""
echo "🔨 Rebuilding containers..."
docker compose build --no-cache api

echo ""
echo "▶️  Starting containers..."
docker compose up -d

# Wait for startup
echo ""
echo "⏳ Waiting for startup..."
sleep 15

# Test the setup
echo ""
echo "🧪 Testing the setup..."
CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container not found"
    exit 1
fi

echo "✅ Container is running (ID: $CONTAINER_ID)"

# Check if our files are mounted correctly
echo ""
echo "🔍 Checking if files are mounted correctly..."

if docker exec "$CONTAINER_ID" grep -q "fetchUserModelsController" "/app/api/server/controllers/ModelController.js" 2>/dev/null; then
    echo "✅ fetchUserModelsController function found in container"
else
    echo "❌ fetchUserModelsController function not found in container"
fi

if docker exec "$CONTAINER_ID" grep -q "useAutoModelRefresh" "/app/client/src/routes/Root.tsx" 2>/dev/null; then
    echo "✅ useAutoModelRefresh hook integrated in container"
else
    echo "❌ useAutoModelRefresh hook not integrated in container"
fi

# Test API endpoint
echo ""
echo "🔍 Testing API endpoint..."
API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3080/api/models/fetch 2>/dev/null || echo "000")

if [ "$API_RESPONSE" = "401" ]; then
    echo "✅ /api/models/fetch endpoint is accessible (401 = auth required)"
elif [ "$API_RESPONSE" = "200" ]; then
    echo "✅ /api/models/fetch endpoint is working"
else
    echo "❌ /api/models/fetch endpoint not accessible (HTTP $API_RESPONSE)"
fi

echo ""
echo "🎉 Docker fix complete!"
echo ""
echo "📋 Next steps:"
echo "1. Open LibreChat in your browser at http://your-server:3080"
echo "2. Go to Settings and enter your LiteLLM API key"
echo "3. Check browser console (F12) for debug messages"
echo "4. Check server logs: docker compose logs -f api | grep 'Dynamic'"
echo ""
echo "🔍 Look for these debug messages:"
echo "- '[Dynamic Model Fetch] Controller called' - Server-side"
echo "- '[Dynamic Model Fetch] Fetching models' - Client-side"
