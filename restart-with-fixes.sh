#!/bin/bash

echo "🔄 Restarting LibreChat with Fixed Imports"
echo "=========================================="

# Stop the container
echo "🛑 Stopping container..."
docker compose down

# Start the container (this will pick up the volume mount changes)
echo "🚀 Starting container with updated volume mounts..."
docker compose up -d

# Wait for startup
echo "⏳ Waiting for container to start..."
sleep 15

# Verify the container is running and check the file
CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container failed to start"
    exit 1
fi

echo "✅ Container running: $CONTAINER_ID"

# Check that the updated file is now mounted
echo ""
echo "🔍 Verifying updated file is mounted..."
docker exec "$CONTAINER_ID" cat /app/client/src/hooks/Input/useUserKey.ts | head -8

# Now try the client build
echo ""
echo "🔨 Building client with fixed imports..."
if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm run build" 2>/dev/null; then
    echo "✅ Client build successful!"
    echo ""
    echo "🎉 SUCCESS! The dynamic model fetching should now work."
    echo ""
    echo "📋 Next steps:"
    echo "1. Open LibreChat at http://your-server:3080"
    echo "2. Login and go to Settings/Model Selection"
    echo "3. Enter your LiteLLM API key"
    echo "4. Check browser console for debug messages"
    echo "5. Models dropdown should update with your LiteLLM models"
else
    echo "❌ Client build still failed"
    echo "Checking build logs..."
    docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm run build" 2>&1 | tail -10
fi
