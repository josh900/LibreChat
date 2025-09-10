#!/bin/bash

echo "🔨 Rebuilding Client with Modified Source Files"
echo "==============================================="

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container not running"
    exit 1
fi

echo "✅ Container: $CONTAINER_ID"

# Step 1: Verify our source files are mounted
echo ""
echo "🔍 Step 1: Verifying source files are mounted..."

if docker exec "$CONTAINER_ID" test -f "/app/client/src/hooks/Input/useUserKey.ts" 2>/dev/null; then
    echo "✅ Source file mounted: useUserKey.ts"
    docker exec "$CONTAINER_ID" grep -q "Dynamic Model Fetch" /app/client/src/hooks/Input/useUserKey.ts 2>/dev/null && echo "✅ Contains our modifications" || echo "❌ Missing our modifications"
else
    echo "❌ Source file not mounted"
    exit 1
fi

if docker exec "$CONTAINER_ID" test -f "/app/client/src/hooks/Input/useAutoModelRefresh.ts" 2>/dev/null; then
    echo "✅ Source file mounted: useAutoModelRefresh.ts"
    docker exec "$CONTAINER_ID" grep -q "useAutoModelRefresh" /app/client/src/hooks/Input/useAutoModelRefresh.ts 2>/dev/null && echo "✅ Contains our modifications" || echo "❌ Missing our modifications"
else
    echo "❌ Source file not mounted"
    exit 1
fi

# Step 2: Install dependencies (using sh instead of bash)
echo ""
echo "🔍 Step 2: Installing client dependencies..."

if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm install" 2>/dev/null; then
    echo "✅ Client dependencies installed"
else
    echo "❌ Failed to install client dependencies"
    echo "Trying alternative approach..."
    # Try installing bash first if possible
    if docker exec "$CONTAINER_ID" sh -c "which apk" >/dev/null 2>&1; then
        echo "Installing bash using apk..."
        docker exec "$CONTAINER_ID" sh -c "apk add --no-cache bash" 2>/dev/null || true
    elif docker exec "$CONTAINER_ID" sh -c "which apt-get" >/dev/null 2>&1; then
        echo "Installing bash using apt-get..."
        docker exec "$CONTAINER_ID" sh -c "apt-get update && apt-get install -y bash" 2>/dev/null || true
    fi

    # Try again with bash if it was installed
    if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm install" 2>/dev/null; then
        echo "✅ Client dependencies installed (retry)"
    else
        echo "❌ Still failed to install dependencies"
        echo "Manual installation required:"
        echo "docker exec $CONTAINER_ID sh -c 'cd /app/client && npm install'"
        exit 1
    fi
fi

# Step 3: Build the client (using sh instead of bash)
echo ""
echo "🔍 Step 3: Building client with our modifications..."

if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm run build" 2>/dev/null; then
    echo "✅ Client built successfully"
else
    echo "❌ Client build failed"
    echo "Checking build logs..."
    docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm run build" 2>&1 | tail -20
    exit 1
fi

# Step 4: Verify build output
echo ""
echo "🔍 Step 4: Verifying build output..."

if docker exec "$CONTAINER_ID" test -d "/app/client/build" 2>/dev/null; then
    echo "✅ Build directory exists"
    docker exec "$CONTAINER_ID" ls -la /app/client/build/ | head -5
else
    echo "❌ Build directory missing"
    exit 1
fi

# Step 5: Check if our code is in the built files
echo ""
echo "🔍 Step 5: Checking if our modifications are in built files..."

# Look for our debug messages in built files
if docker exec "$CONTAINER_ID" find /app/client/build -name "*.js" -exec grep -l "Dynamic Model Fetch" {} \; 2>/dev/null | head -3; then
    echo "✅ Found 'Dynamic Model Fetch' in built files"
else
    echo "❌ 'Dynamic Model Fetch' not found in built files"
fi

if docker exec "$CONTAINER_ID" find /app/client/build -name "*.js" -exec grep -l "useAutoModelRefresh" {} \; 2>/dev/null | head -3; then
    echo "✅ Found 'useAutoModelRefresh' in built files"
else
    echo "❌ 'useAutoModelRefresh' not found in built files"
fi

# Step 6: Restart the API server to pick up changes
echo ""
echo "🔍 Step 6: Restarting API server..."

# Stop just the API container
docker compose stop api

# Start it again
docker compose start api

# Wait for startup
echo "⏳ Waiting for API server to restart..."
sleep 10

# Verify it's running
if docker compose ps | grep -q "LibreChat.*Up"; then
    echo "✅ API server restarted successfully"
else
    echo "❌ API server failed to restart"
    exit 1
fi

echo ""
echo "🎉 Client rebuild completed!"
echo ""
echo "📋 Next steps:"
echo "1. Clear your browser cache (Ctrl+F5 or Cmd+Shift+R)"
echo "2. Open LibreChat at http://your-server:3080"
echo "3. Login and go to Settings/Model Selection"
echo "4. Enter your LiteLLM API key"
echo "5. Check browser console for our debug messages"
echo "6. Check server logs: docker compose logs -f api | grep Dynamic"
echo ""
echo "Expected results:"
echo "✅ Browser console: '[Dynamic Model Fetch] Fetching models...'"
echo "✅ Server logs: '[Dynamic Model Fetch] Controller called...'"
echo "✅ Models dropdown updates with your LiteLLM models"