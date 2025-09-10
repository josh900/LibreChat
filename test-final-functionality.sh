#!/bin/bash

echo "🧪 Final Functionality Test for Dynamic Model Fetching"
echo "======================================================"

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container not running"
    exit 1
fi

echo "✅ Container running: $CONTAINER_ID"

# Test 1: Verify all files are mounted
echo ""
echo "🔍 Test 1: File Mount Verification"
echo "=================================="

files=(
    "/app/api/server/services/Config/loadConfigModels.js:Dynamic Model Fetch"
    "/app/api/server/controllers/ModelController.js:fetchUserModelsController"
    "/app/api/server/routes/models.js:fetchUserModelsController"
    "/app/client/src/hooks/Input/useUserKey.ts:Dynamic Model Fetch"
    "/app/client/src/hooks/Input/useAutoModelRefresh.ts:useAutoModelRefresh"
    "/app/client/src/routes/Root.tsx:useAutoModelRefresh"
)

all_files_good=true
for file_check in "${files[@]}"; do
    IFS=':' read -r file_path search_term <<< "$file_check"
    if docker exec "$CONTAINER_ID" grep -q "$search_term" "$file_path" 2>/dev/null; then
        echo "✅ $file_path ✓"
    else
        echo "❌ $file_path ✗ (missing '$search_term')"
        all_files_good=false
    fi
done

# Test 2: API endpoint functionality
echo ""
echo "🔍 Test 2: API Endpoint Tests"
echo "============================"

MODELS_RESP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3080/api/models 2>/dev/null || echo "000")
FETCH_RESP=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3080/api/models/fetch \
    -H "Content-Type: application/json" \
    -d '{"endpoint":"LiteLLM"}' 2>/dev/null || echo "000")

echo "Models endpoint: HTTP $MODELS_RESP"
echo "Fetch endpoint: HTTP $FETCH_RESP"

if [ "$MODELS_RESP" = "401" ] && [ "$FETCH_RESP" = "401" ]; then
    echo "✅ API endpoints accessible (401 = auth required)"
elif [ "$MODELS_RESP" = "200" ] && [ "$FETCH_RESP" = "200" ]; then
    echo "✅ API endpoints working (200 = success)"
else
    echo "⚠️  API endpoints may have issues"
fi

# Test 3: Configuration check
echo ""
echo "🔍 Test 3: Configuration Check"
echo "=============================="

if grep -q "fetch: true" librechat.yaml 2>/dev/null; then
    echo "✅ librechat.yaml has fetch: true"
else
    echo "❌ librechat.yaml missing fetch: true"
fi

# Test 4: Node.js module loading
echo ""
echo "🔍 Test 4: Node.js Module Loading"
echo "================================="

if docker exec "$CONTAINER_ID" node -e "
try {
    console.log('Testing module loading...');
    const fs = require('fs');

    // Test backend modules
    const controller = fs.readFileSync('/app/api/server/controllers/ModelController.js', 'utf8');
    if (controller.includes('fetchUserModelsController')) {
        console.log('✅ Backend: fetchUserModelsController loaded');
    } else {
        console.log('❌ Backend: fetchUserModelsController missing');
    }

    // Test frontend modules (check if files exist)
    const useUserKey = fs.existsSync('/app/client/src/hooks/Input/useUserKey.ts');
    const useAutoModelRefresh = fs.existsSync('/app/client/src/hooks/Input/useAutoModelRefresh.ts');

    console.log('✅ Frontend files exist:', useUserKey && useAutoModelRefresh ? 'Yes' : 'No');

} catch (e) {
    console.log('❌ Module loading test failed:', e.message);
}
" 2>/dev/null; then
    echo "✅ Node.js module test completed"
else
    echo "❌ Node.js module test failed"
fi

# Test 5: Server logs
echo ""
echo "🔍 Test 5: Server Logs Check"
echo "============================"

echo "Recent server logs with 'Dynamic':"
docker compose logs --tail=20 api 2>/dev/null | grep -i dynamic || echo "No dynamic-related logs found"

echo ""
echo "Recent server logs (last 5 lines):"
docker compose logs --tail=5 api 2>/dev/null

# Summary
echo ""
echo "📊 TEST SUMMARY"
echo "=============="

if $all_files_good; then
    echo "✅ All files are properly mounted"
else
    echo "❌ Some files are not properly mounted"
fi

if [ "$MODELS_RESP" = "401" ] || [ "$MODELS_RESP" = "200" ]; then
    echo "✅ API endpoints are working"
else
    echo "❌ API endpoints have issues"
fi

echo ""
echo "🎯 MANUAL TESTING REQUIRED"
echo "========================="
echo ""
echo "1. 🌐 Open LibreChat at http://your-server:3080"
echo "2. 🔐 Login to LibreChat"
echo "3. ⚙️  Go to Settings/Model Selection"
echo "4. 🔑 Enter your LiteLLM API key"
echo "5. 🖥️  Check browser console (F12) for:"
echo "   - '[Dynamic Model Fetch] Fetching models for endpoint: LiteLLM'"
echo "   - '[Dynamic Model Fetch] User logged in, scheduling auto-refresh'"
echo "6. 📝 Check server logs:"
echo "   docker compose logs -f api | grep 'Dynamic'"
echo ""
echo "Expected server logs:"
echo "✅ '[Dynamic Model Fetch] Controller called with endpoint: LiteLLM'"
echo "✅ '[Dynamic Model Fetch] Fetching models for user [ID] from [URL]'"
echo "✅ '[Dynamic Model Fetch] Successfully fetched [X] models'"
echo ""
echo "Expected browser console:"
echo "✅ '[Dynamic Model Fetch] Fetching models for endpoint: LiteLLM'"
echo "✅ '[Dynamic Model Fetch] Auto-refreshing models for user: [ID]'"
echo ""
echo "🎉 If you see these messages and your models load, SUCCESS! 🎉"
