// Simple test script to verify API authentication and model fetching
const API_BASE = 'http://localhost:3080';

async function testAPI() {
    console.log('🧪 Testing LibreChat API endpoints...\n');

    // Test 1: Basic health check
    try {
        const healthResponse = await fetch(`${API_BASE}/api/health`);
        console.log(`✅ Health check: ${healthResponse.status}`);
    } catch (e) {
        console.log(`❌ Health check failed: ${e.message}`);
    }

    // Test 2: Models endpoint (should require auth)
    try {
        const modelsResponse = await fetch(`${API_BASE}/api/models`);
        console.log(`✅ Models endpoint: ${modelsResponse.status} (expected: 401)`);
    } catch (e) {
        console.log(`❌ Models endpoint failed: ${e.message}`);
    }

    // Test 3: Fetch endpoint (should require auth)
    try {
        const fetchResponse = await fetch(`${API_BASE}/api/models/fetch`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ endpoint: 'LiteLLM' })
        });
        console.log(`✅ Fetch endpoint: ${fetchResponse.status} (expected: 401)`);
    } catch (e) {
        console.log(`❌ Fetch endpoint failed: ${e.message}`);
    }

    console.log('\n📋 Next: Test with browser authentication');
    console.log('1. Login to LibreChat in browser');
    console.log('2. Open Developer Tools (F12) > Console');
    console.log('3. Run this code in the browser console:');
    console.log(`
fetch('/api/models/fetch', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + localStorage.getItem('token')
    },
    body: JSON.stringify({ endpoint: 'LiteLLM' })
}).then(r => r.json()).then(console.log);
    `);
}

// Run the test
testAPI();
