#!/bin/bash

echo "🔍 Testing Import Fix"
echo "===================="

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container not running"
    exit 1
fi

echo "✅ Container: $CONTAINER_ID"

# Check the file content
echo ""
echo "🔍 Checking updated file content:"
docker exec "$CONTAINER_ID" cat /app/client/src/hooks/Input/useUserKey.ts | head -5

# Try a quick build test
echo ""
echo "🔍 Testing build dependencies:"
if docker exec "$CONTAINER_ID" sh -c "cd /app/client && npm list vite" >/dev/null 2>&1; then
    echo "✅ Vite is installed"
else
    echo "❌ Vite not found"
fi

# Check if the build command works
echo ""
echo "🔍 Testing build command:"
if docker exec "$CONTAINER_ID" sh -c "cd /app/client && timeout 10 npm run build 2>&1 | head -5" 2>/dev/null; then
    echo "✅ Build command runs"
else
    echo "⚠️  Build command has issues"
fi

echo ""
echo "🎯 Ready to try full rebuild!"
echo "Run: ./rebuild-client.sh"
