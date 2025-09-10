#!/bin/bash

echo "🔍 Verifying Frontend Code Loading"
echo "=================================="

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container not running"
    exit 1
fi

echo "✅ Container: $CONTAINER_ID"

# Check if our frontend files are actually being served
echo ""
echo "🔍 Checking if frontend files contain our modifications..."

# Test 1: Check if the container's frontend files have our modifications
echo ""
echo "Test 1: Container Frontend Files"
echo "-------------------------------"

# Check if our React components are in the built files
if docker exec "$CONTAINER_ID" find /app -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" | head -10 | xargs docker exec "$CONTAINER_ID" grep -l "Dynamic Model Fetch" 2>/dev/null | head -5; then
    echo "✅ Found 'Dynamic Model Fetch' in built frontend files"
else
    echo "❌ 'Dynamic Model Fetch' not found in built frontend files"
fi

# Check if useAutoModelRefresh is referenced
if docker exec "$CONTAINER_ID" find /app -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" | xargs docker exec "$CONTAINER_ID" grep -l "useAutoModelRefresh" 2>/dev/null | head -5; then
    echo "✅ Found 'useAutoModelRefresh' in built frontend files"
else
    echo "❌ 'useAutoModelRefresh' not found in built frontend files"
fi

# Test 2: Check if the client build exists and is recent
echo ""
echo "Test 2: Client Build Status"
echo "--------------------------"

if docker exec "$CONTAINER_ID" test -d "/app/client/build" 2>/dev/null; then
    echo "✅ Client build directory exists"
    docker exec "$CONTAINER_ID" ls -la /app/client/build/ | head -10
else
    echo "❌ Client build directory missing"
fi

# Test 3: Check if the app is serving our source files or built files
echo ""
echo "Test 3: File Serving Check"
echo "-------------------------"

# Check what files are actually being served
echo "Checking what files are mounted vs built..."
docker exec "$CONTAINER_ID" ls -la /app/client/src/hooks/Input/ 2>/dev/null || echo "Source hooks directory not accessible"

# Test 4: Check if we need to rebuild the client
echo ""
echo "Test 4: Client Rebuild Check"
echo "---------------------------"

echo "To rebuild the client with our changes, run:"
echo "docker exec $CONTAINER_ID sh -c 'cd /app/client && npm run build'"

echo ""
echo "Or restart with client rebuild:"
echo "docker exec $CONTAINER_ID sh -c 'cd /app/client && npm install && npm run build && cd /app && npm run start'"

# Test 5: Manual verification
echo ""
echo "Test 5: Manual Verification Steps"
echo "--------------------------------"

echo "1. Open browser Developer Tools (F12)"
echo "2. Go to Network tab"
echo "3. Filter for 'models' or 'fetch'"
echo "4. Enter API key in LibreChat settings"
echo "5. Look for network requests to /api/models/fetch"
echo ""
echo "Expected network calls:"
echo "- POST /api/models/fetch (when entering API key)"
echo "- GET /api/models (when loading model list)"
echo ""
echo "If you don't see these network calls, the frontend isn't triggering our code."

# Test 6: Check if the React app is using our source files
echo ""
echo "Test 6: Source File Access"
echo "-------------------------"

if docker exec "$CONTAINER_ID" test -f "/app/client/src/hooks/Input/useUserKey.ts" 2>/dev/null; then
    echo "✅ Source file exists in container"
    docker exec "$CONTAINER_ID" head -5 /app/client/src/hooks/Input/useUserKey.ts 2>/dev/null
else
    echo "❌ Source file not found in container"
fi
