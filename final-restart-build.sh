#!/bin/bash

echo "🎯 Final Restart and Build with Fixed Scripts"
echo "============================================="

# Stop the container
echo "🛑 Stopping container..."
docker compose down

# Start the container (this will pick up the updated package.json)
echo "🚀 Starting container with updated package.json..."
docker compose up -d

# Wait for startup
echo "⏳ Waiting for container to start..."
sleep 15

# Get container ID
CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container failed to start"
    exit 1
fi

echo "✅ Container running: $CONTAINER_ID"

# Verify the updated package.json is mounted
echo ""
echo "🔍 Verifying updated package.json is mounted..."
docker exec "$CONTAINER_ID" grep -A 2 -B 2 "npx vite build" /app/client/package.json

# Try the build
echo ""
echo "🔨 Building client with npx vite..."
if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm run build" 2>/dev/null; then
    echo "✅ BUILD SUCCESSFUL! 🎉"
    echo ""
    echo "📋 Your dynamic model fetching is now working!"
    echo ""
    echo "🌐 Test it:"
    echo "1. Open LibreChat at http://your-server:3080"
    echo "2. Login and go to Settings/Model Selection"
    echo "3. Enter your LiteLLM API key"
    echo "4. Models dropdown should update with your LiteLLM models"
    echo ""
    echo "🔍 Debug messages to look for:"
    echo "- Browser console: '[Dynamic Model Fetch] Fetching models...'"
    echo "- Server logs: '[Dynamic Model Fetch] Controller called...'"
else
    echo "❌ Build still failed"
    echo "Checking error details..."
    docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm run build" 2>&1 | tail -10
fi

# Check build results
echo ""
echo "🔍 Checking build results..."
if docker exec "$CONTAINER_ID" test -d "/app/client/build" 2>/dev/null; then
    echo "✅ Build directory exists!"
    docker exec "$CONTAINER_ID" ls -la /app/client/build/ | head -5
else
    echo "❌ Build directory not found"
fi
