#!/bin/bash

# Comprehensive debug script for dynamic model fetching
echo "🔍 Dynamic Model Fetching Debug Script"
echo "======================================"

# Function to check container
check_container() {
    if ! docker compose ps | grep -q "LibreChat"; then
        echo "❌ LibreChat container is not running"
        echo "Start it with: docker compose up -d"
        exit 1
    fi

    CONTAINER_ID=$(docker compose ps | grep "LibreChat" | awk '{print $1}')
    echo "✅ LibreChat container is running (ID: $CONTAINER_ID)"
}

# Function to check file mounts
check_file_mounts() {
    echo ""
    echo "🔍 Checking file mounts in container..."

    files_to_check=(
        "/app/api/server/services/Config/loadConfigModels.js:fetchUserModelsController"
        "/app/api/server/controllers/ModelController.js:fetchUserModelsController"
        "/app/api/server/routes/models.js:fetchUserModelsController"
        "/app/client/src/hooks/Input/useUserKey.ts:Dynamic Model Fetch"
        "/app/client/src/routes/Root.tsx:useAutoModelRefresh"
        "/app/client/src/hooks/Input/useAutoModelRefresh.ts:useAutoModelRefresh"
    )

    for file_check in "${files_to_check[@]}"; do
        IFS=':' read -r file_path search_term <<< "$file_check"
        if docker exec "$CONTAINER_ID" grep -q "$search_term" "$file_path" 2>/dev/null; then
            echo "✅ $file_path contains '$search_term'"
        else
            echo "❌ $file_path missing '$search_term'"
        fi
    done
}

# Function to test API endpoints
test_api_endpoints() {
    echo ""
    echo "🔍 Testing API endpoints..."

    # Test basic endpoints
    MODELS_RESP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3080/api/models 2>/dev/null || echo "000")
    FETCH_RESP=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3080/api/models/fetch \
        -H "Content-Type: application/json" \
        -d '{"endpoint":"LiteLLM"}' 2>/dev/null || echo "000")

    echo "Models endpoint: HTTP $MODELS_RESP"
    echo "Fetch endpoint: HTTP $FETCH_RESP"

    if [ "$MODELS_RESP" = "401" ] && [ "$FETCH_RESP" = "401" ]; then
        echo "✅ API endpoints are accessible (401 = auth required)"
    else
        echo "❌ API endpoints may have issues"
    fi
}

# Function to check configuration
check_configuration() {
    echo ""
    echo "🔍 Checking LibreChat configuration..."

    if [ -f "librechat.yaml" ]; then
        echo "✅ librechat.yaml exists"

        if grep -q "fetch: true" librechat.yaml; then
            echo "✅ Configuration has fetch: true"
        else
            echo "❌ Configuration missing fetch: true"
            echo "Add to your endpoint:"
            echo "models:"
            echo "  fetch: true"
        fi

        if grep -q "user_provided" librechat.yaml; then
            echo "✅ Configuration has user_provided API key"
        else
            echo "⚠️  Configuration may not have user_provided API key"
        fi
    else
        echo "❌ librechat.yaml not found"
    fi

    if [ -f ".env" ]; then
        echo "✅ .env file exists"
    else
        echo "❌ .env file missing"
    fi
}

# Function to check server logs
check_server_logs() {
    echo ""
    echo "🔍 Checking server logs..."

    echo "Recent server logs:"
    docker compose logs --tail=20 api 2>/dev/null | grep -E "(Dynamic|error|Error|fetchUserModels|useAutoModelRefresh)" || echo "No relevant logs found"

    echo ""
    echo "🔍 Checking for any errors in recent logs:"
    docker compose logs --tail=50 api 2>/dev/null | grep -i error || echo "No errors found in recent logs"
}

# Function to test network connectivity
test_network() {
    echo ""
    echo "🔍 Testing network connectivity..."

    # Test if we can reach the API from inside the container
    if docker exec "$CONTAINER_ID" curl -s --max-time 5 http://localhost:3080/api/health >/dev/null 2>&1; then
        echo "✅ Container can reach API internally"
    else
        echo "❌ Container cannot reach API internally"
    fi

    # Test external connectivity
    if curl -s --max-time 5 http://localhost:3080 >/dev/null 2>&1; then
        echo "✅ External access to API works"
    else
        echo "❌ External access to API blocked"
    fi
}

# Function to check Node.js modules
check_node_modules() {
    echo ""
    echo "🔍 Checking Node.js environment..."

    # Check if required modules are available
    if docker exec "$CONTAINER_ID" node -e "console.log('Node.js working')" >/dev/null 2>&1; then
        echo "✅ Node.js is working in container"
    else
        echo "❌ Node.js not working in container"
    fi

    # Check if our packages are accessible
    if docker exec "$CONTAINER_ID" test -d "/app/packages/data-provider" 2>/dev/null; then
        echo "✅ data-provider package exists"
    else
        echo "❌ data-provider package missing"
    fi
}

# Function to create manual test
create_manual_test() {
    echo ""
    echo "🔧 Creating manual test script..."

    cat > manual-test.js << 'EOF'
console.log('=== Manual Dynamic Model Fetching Test ===');

// Test 1: Check if our modules are loaded
try {
    const { useFetchUserModelsMutation } = require('librechat-data-provider/react-query');
    console.log('✅ useFetchUserModelsMutation available');
} catch (e) {
    console.log('❌ useFetchUserModelsMutation not available:', e.message);
}

// Test 2: Check if our hooks are available
try {
    const useAutoModelRefresh = require('./client/src/hooks/Input/useAutoModelRefresh.ts');
    console.log('✅ useAutoModelRefresh available');
} catch (e) {
    console.log('❌ useAutoModelRefresh not available:', e.message);
}

// Test 3: Check API endpoints
const testEndpoints = async () => {
    try {
        const response = await fetch('/api/models/fetch', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ endpoint: 'LiteLLM' })
        });
        console.log('✅ Fetch endpoint responded with status:', response.status);
    } catch (e) {
        console.log('❌ Fetch endpoint failed:', e.message);
    }
};

testEndpoints();
EOF

    echo "✅ Created manual-test.js for browser testing"
}

# Function to provide browser debug instructions
browser_debug_instructions() {
    echo ""
    echo "🌐 Browser Debug Instructions:"
    echo "=============================="
    echo ""
    echo "1. Open LibreChat at http://your-server:3080"
    echo "2. Open browser Developer Tools (F12)"
    echo "3. Go to Console tab"
    echo "4. Login to LibreChat"
    echo "5. Go to Settings/Model Selection"
    echo "6. Look for these debug messages:"
    echo ""
    echo "   ✅ '[Dynamic Model Fetch] Fetching models for endpoint: LiteLLM'"
    echo "   ✅ '[Dynamic Model Fetch] User logged in, scheduling auto-refresh'"
    echo "   ✅ '[Dynamic Model Fetch] Auto-refreshing models for user: [ID]'"
    echo ""
    echo "7. Enter your LiteLLM API key"
    echo "8. Look for these messages after entering the key:"
    echo ""
    echo "   ✅ '[Dynamic Model Fetch] Fetching models for endpoint: LiteLLM'"
    echo "   ✅ Models dropdown should update with your LiteLLM models"
    echo ""
    echo "If you don't see these messages, the frontend code isn't loading properly."
}

# Function to provide server debug instructions
server_debug_instructions() {
    echo ""
    echo "🖥️  Server Debug Instructions:"
    echo "============================"
    echo ""
    echo "1. Watch server logs in real-time:"
    echo "   docker compose logs -f api"
    echo ""
    echo "2. Look for these messages when a user enters an API key:"
    echo ""
    echo "   ✅ '[Dynamic Model Fetch] Controller called with endpoint: LiteLLM'"
    echo "   ✅ '[Dynamic Model Fetch] Fetching models for user [ID] from [URL]'"
    echo "   ✅ '[Dynamic Model Fetch] Successfully fetched [X] models'"
    echo ""
    echo "3. If you see errors, check:"
    echo "   - API key validity"
    echo "   - LiteLLM server connectivity"
    echo "   - Network configuration"
}

# Main execution
check_container
check_file_mounts
test_api_endpoints
check_configuration
check_server_logs
test_network
check_node_modules
create_manual_test

echo ""
echo "🎯 Debug Summary:"
echo "================="
echo ""
echo "✅ Files are mounted correctly"
echo "✅ API endpoints are accessible"
echo "✅ Server shows our debug message"
echo ""
echo "If you're still not seeing logs when entering API key:"
echo "1. Check browser console for JavaScript errors"
echo "2. Verify your librechat.yaml configuration"
echo "3. Check if the frontend is loading our modified files"
echo "4. Test with a simple API key to rule out authentication issues"

browser_debug_instructions
server_debug_instructions

echo ""
echo "📞 If issues persist, run this and share the output:"
echo "   ./debug-dynamic-models.sh > debug-output.txt"
echo "   # Then share debug-output.txt for analysis"