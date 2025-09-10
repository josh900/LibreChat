#!/bin/bash

echo "🌐 Checking Docker Network Configuration"
echo "======================================="

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container not running"
    exit 1
fi

echo "✅ Container: $CONTAINER_ID"

# Check container network
echo ""
echo "🔍 Container network info:"
docker inspect "$CONTAINER_ID" | grep -A 10 "NetworkSettings"

# Test internal connectivity
echo ""
echo "🔍 Testing internal connectivity:"
echo "Container to localhost:3080"
docker exec "$CONTAINER_ID" curl -s --max-time 5 http://localhost:3080/api/health || echo "❌ Failed"

echo "Container to 127.0.0.1:3080"
docker exec "$CONTAINER_ID" curl -s --max-time 5 http://127.0.0.1:3080/api/health || echo "❌ Failed"

echo "Container to 0.0.0.0:3080"
docker exec "$CONTAINER_ID" curl -s --max-time 5 http://0.0.0.0:3080/api/health || echo "❌ Failed"

# Check environment variables
echo ""
echo "🔍 Environment variables in container:"
docker exec "$CONTAINER_ID" env | grep -E "(HOST|PORT|NODE_ENV)" || echo "❌ Environment variables not found"

# Check if the app is listening on the right interface
echo ""
echo "🔍 Checking what the app is listening on:"
docker exec "$CONTAINER_ID" netstat -tlnp 2>/dev/null | grep :3080 || echo "❌ Nothing listening on 3080"

echo ""
echo "🔧 If internal connectivity fails, the issue might be:"
echo "- App not binding to 0.0.0.0 inside container"
echo "- Docker network configuration"
echo "- HOST environment variable not set correctly"
