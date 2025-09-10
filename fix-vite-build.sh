#!/bin/bash

echo "🔧 Fixing Vite Build Issue"
echo "=========================="

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container not running"
    exit 1
fi

echo "✅ Container: $CONTAINER_ID"

# Check if vite is installed
echo ""
echo "🔍 Checking vite installation..."
if docker exec "$CONTAINER_ID" sh -c "cd /app/client && ls node_modules/.bin/vite" 2>/dev/null; then
    echo "✅ Vite binary exists in node_modules/.bin/"
else
    echo "❌ Vite binary not found in node_modules/.bin/"
    echo "Installing vite..."
    docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm install vite --save-dev" 2>/dev/null || echo "Failed to install vite"
fi

# Check PATH
echo ""
echo "🔍 Checking PATH..."
docker exec "$CONTAINER_ID" sh -c "echo \$PATH"

# Try using npx to run vite
echo ""
echo "🔍 Trying build with npx..."
if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npx vite build --version" 2>/dev/null; then
    echo "✅ npx vite works"
else
    echo "❌ npx vite failed"
fi

# Try the build with npx
echo ""
echo "🔨 Building with npx vite..."
if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npx vite build" 2>/dev/null; then
    echo "✅ Build successful with npx!"
else
    echo "❌ Build failed with npx, trying alternative approach..."
    # Try updating the build script to use npx
    echo "Updating package.json build script..."
    docker exec "$CONTAINER_ID" sh -c "cd /app/client && sed -i 's/vite build/npx vite build/g' package.json" 2>/dev/null || echo "Failed to update build script"
fi

# Try the build again with updated script
echo ""
echo "🔨 Trying build with updated script..."
if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm run build" 2>/dev/null; then
    echo "✅ Build successful!"
else
    echo "❌ Build still failed"
    echo "Checking detailed error logs..."
    docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm run build" 2>&1 | tail -20
fi

# Check if build directory was created
echo ""
echo "🔍 Checking build results..."
if docker exec "$CONTAINER_ID" test -d "/app/client/build" 2>/dev/null; then
    echo "✅ Build directory created successfully!"
    docker exec "$CONTAINER_ID" ls -la /app/client/build/ | head -5
else
    echo "❌ Build directory not found"
fi
