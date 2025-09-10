#!/bin/bash

echo "🎯 Verifying Dynamic Model Fetching is Working"
echo "============================================="

CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ LibreChat container not running"
    exit 1
fi

echo "✅ Container: $CONTAINER_ID"

# Test 1: Check if built files contain our modifications
echo ""
echo "🔍 Test 1: Built Files Check"
echo "==========================="

if docker exec "$CONTAINER_ID" find /app/client/build -name "*.js" -exec grep -l "Dynamic Model Fetch" {} \; 2>/dev/null | wc -l | grep -q "^[1-9]"; then
    echo "✅ Built files contain 'Dynamic Model Fetch' debug messages"
else
    echo "❌ Built files missing 'Dynamic Model Fetch' debug messages"
    echo "   → Run: ./rebuild-client.sh"
fi

if docker exec "$CONTAINER_ID" find /app/client/build -name "*.js" -exec grep -l "useAutoModelRefresh" {} \; 2>/dev/null | wc -l | grep -q "^[1-9]"; then
    echo "✅ Built files contain 'useAutoModelRefresh' hook"
else
    echo "❌ Built files missing 'useAutoModelRefresh' hook"
    echo "   → Run: ./rebuild-client.sh"
fi

# Test 2: API endpoints
echo ""
echo "🔍 Test 2: API Endpoints"
echo "======================="

MODELS_RESP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3080/api/models 2>/dev/null || echo "000")
FETCH_RESP=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3080/api/models/fetch \
    -H "Content-Type: application/json" \
    -d '{"endpoint":"LiteLLM"}' 2>/dev/null || echo "000")

echo "Models endpoint: HTTP $MODELS_RESP"
echo "Fetch endpoint: HTTP $FETCH_RESP"

if [ "$MODELS_RESP" = "401" ] && [ "$FETCH_RESP" = "401" ]; then
    echo "✅ API endpoints working (401 = auth required)"
elif [ "$MODELS_RESP" = "200" ] && [ "$FETCH_RESP" = "200" ]; then
    echo "✅ API endpoints working (200 = success)"
else
    echo "❌ API endpoints not working properly"
fi

# Test 3: Server logs
echo ""
echo "🔍 Test 3: Server Logs"
echo "====================="

echo "Recent server logs:"
docker compose logs --tail=10 api 2>/dev/null | grep -E "(Dynamic|error|Error)" || echo "No relevant logs"

# Test 4: Configuration
echo ""
echo "🔍 Test 4: Configuration"
echo "======================="

if grep -q "fetch: true" librechat.yaml 2>/dev/null; then
    echo "✅ librechat.yaml has fetch: true"
else
    echo "❌ librechat.yaml missing fetch: true"
fi

# Summary and next steps
echo ""
echo "📊 VERIFICATION SUMMARY"
echo "======================"

echo ""
echo "🎯 MANUAL TESTING REQUIRED"
echo "========================="
echo ""
echo "1. 🌐 Open LibreChat: http://your-server:3080"
echo "2. 🔐 Login to LibreChat"
echo "3. 🧹 Clear browser cache: Ctrl+F5 (or Cmd+Shift+R)"
echo "4. ⚙️  Go to Settings/Model Selection"
echo "5. 🔑 Enter your LiteLLM API key"
echo ""
echo "6. 🖥️  CHECK BROWSER CONSOLE (F12):"
echo "   Expected messages:"
echo "   ✅ '[Dynamic Model Fetch] Fetching models for endpoint: LiteLLM'"
echo "   ✅ '[Dynamic Model Fetch] User logged in, scheduling auto-refresh'"
echo "   ✅ '[Dynamic Model Fetch] Auto-refreshing models for user: [ID]'"
echo ""
echo "7. 📝 CHECK SERVER LOGS:"
echo "   docker compose logs -f api | grep 'Dynamic'"
echo "   Expected messages:"
echo "   ✅ '[Dynamic Model Fetch] Controller called with endpoint: LiteLLM'"
echo "   ✅ '[Dynamic Model Fetch] Fetching models for user [ID] from [URL]'"
echo "   ✅ '[Dynamic Model Fetch] Successfully fetched [X] models'"
echo ""
echo "8. 🎯 CHECK MODELS DROPDOWN:"
echo "   ✅ Should show your LiteLLM models instead of default ones"
echo "   ✅ Models should update after entering API key"
echo ""
echo "🎉 IF YOU SEE ALL THESE - SUCCESS! 🎉"
echo ""
echo "📞 TROUBLESHOOTING:"
echo "- No console messages → Frontend not rebuilt: Run ./rebuild-client.sh"
echo "- No server logs → API not called: Check browser network tab"
echo "- No models → API failed: Check server logs for errors"
echo "- Still default models → Configuration issue: Check librechat.yaml"
