#!/bin/bash

echo "⚡ Quick Diagnosis for Dynamic Model Fetching"
echo "==========================================="

# Check if LibreChat is running
if ! docker compose ps | grep -q "LibreChat"; then
    echo "❌ LibreChat container not running"
    exit 1
fi

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

echo "✅ Container running: $CONTAINER_ID"

# 1. Check if our files are mounted and contain expected content
echo ""
echo "🔍 1. Checking file mounts..."
files=(
    "/app/api/server/controllers/ModelController.js:fetchUserModelsController"
    "/app/client/src/hooks/Input/useUserKey.ts:Dynamic Model Fetch"
    "/app/client/src/hooks/Input/useAutoModelRefresh.ts:useAutoModelRefresh"
)

for file in "${files[@]}"; do
    IFS=':' read -r path content <<< "$file"
    if docker exec "$CONTAINER_ID" grep -q "$content" "$path" 2>/dev/null; then
        echo "✅ $path ✓"
    else
        echo "❌ $path ✗"
    fi
done

# 2. Check configuration
echo ""
echo "🔍 2. Checking configuration..."
if grep -q "fetch: true" librechat.yaml 2>/dev/null; then
    echo "✅ librechat.yaml has fetch: true"
else
    echo "❌ librechat.yaml missing fetch: true"
fi

# 3. Check recent logs
echo ""
echo "🔍 3. Checking recent server logs..."
docker compose logs --tail=10 api 2>/dev/null | grep -E "(Dynamic|error|Error)" || echo "No relevant logs in last 10 lines"

# 4. Test API endpoints
echo ""
echo "🔍 4. Testing API endpoints..."
curl -s -o /dev/null -w "Models: %{http_code}\n" http://localhost:3080/api/models
curl -s -o /dev/null -w "Fetch: %{http_code}\n" -X POST http://localhost:3080/api/models/fetch \
    -H "Content-Type: application/json" \
    -d '{"endpoint":"LiteLLM"}'

# 5. Check if Node.js can load our modules
echo ""
echo "🔍 5. Testing Node.js module loading..."
if docker exec "$CONTAINER_ID" node -e "
try {
    console.log('Testing module loading...');
    // Test if our modified files can be read
    const fs = require('fs');
    const controller = fs.readFileSync('/app/api/server/controllers/ModelController.js', 'utf8');
    if (controller.includes('fetchUserModelsController')) {
        console.log('✅ Controller file contains our code');
    } else {
        console.log('❌ Controller file missing our code');
    }
} catch (e) {
    console.log('❌ Module loading test failed:', e.message);
}
" 2>/dev/null; then
    echo "✅ Node.js module test completed"
else
    echo "❌ Node.js module test failed"
fi

echo ""
echo "🎯 DIAGNOSIS COMPLETE"
echo ""
echo "📋 If issues persist:"
echo "1. Run: ./debug-dynamic-models.sh > debug.log"
echo "2. Open browser-debug-test.html in browser"
echo "3. Check server logs: docker compose logs -f api | grep Dynamic"
echo ""
echo "🔧 Most common fixes:"
echo "- Ensure librechat.yaml has 'fetch: true'"
echo "- Check that API key is valid"
echo "- Verify LiteLLM server is accessible"
echo "- Clear browser cache and reload"
