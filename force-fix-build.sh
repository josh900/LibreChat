#!/bin/bash

echo "🔧 Force Fix Build Script"
echo "========================="

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container not running"
    exit 1
fi

echo "✅ Container: $CONTAINER_ID"

# Copy the updated package.json directly into the container
echo ""
echo "📋 Copying updated package.json to container..."
docker cp client/package.json "$CONTAINER_ID":/app/client/package.json

# Verify the copy worked
echo ""
echo "🔍 Verifying package.json was updated..."
docker exec "$CONTAINER_ID" grep "npx vite build" /app/client/package.json || echo "❌ npx not found in package.json"

# Try the build
echo ""
echo "🔨 Attempting build..."
if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm run build" 2>/dev/null; then
    echo "✅ BUILD SUCCESSFUL! 🎉"
else
    echo "❌ Build failed, checking detailed error..."
    docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm run build" 2>&1 | tail -15
fi

# Check if vite is available via npx
echo ""
echo "🔍 Testing npx vite directly..."
if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npx vite --version" 2>/dev/null; then
    echo "✅ npx vite is available"
else
    echo "❌ npx vite not available"
fi

# Alternative: try building with npx directly
echo ""
echo "🔨 Trying direct npx build..."
if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npx vite build" 2>/dev/null; then
    echo "✅ Direct npx build successful!"
else
    echo "❌ Direct npx build failed"
fi

# Check build results
echo ""
echo "🔍 Checking build results..."
if docker exec "$CONTAINER_ID" test -d "/app/client/dist" 2>/dev/null; then
    echo "✅ Found dist directory (Vite default)"
    docker exec "$CONTAINER_ID" ls -la /app/client/dist/ | head -5
elif docker exec "$CONTAINER_ID" test -d "/app/client/build" 2>/dev/null; then
    echo "✅ Found build directory"
    docker exec "$CONTAINER_ID" ls -la /app/client/build/ | head -5
else
    echo "❌ No build directory found"
fi

echo ""
echo "🎯 If build succeeded, your dynamic model fetching should now work!"
echo ""
echo "🌐 Test it:"
echo "1. Open LibreChat at http://your-server:3080"
echo "2. Login and enter your LiteLLM API key"
echo "3. Models should update dynamically"
