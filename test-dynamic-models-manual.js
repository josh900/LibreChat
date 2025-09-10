// Manual test for dynamic model fetching
// Run this in the browser console after logging into LibreChat

console.log('🧪 Testing Dynamic Model Fetching...');

// Test 1: Check if our API endpoints exist
async function testEndpoints() {
    console.log('1. Testing API endpoints...');

    try {
        // Test models endpoint
        const modelsResponse = await fetch('/api/models');
        console.log('✅ Models endpoint:', modelsResponse.status);

        // Test fetch endpoint (should return 401 without auth)
        const fetchResponse = await fetch('/api/models/fetch', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ endpoint: 'LiteLLM' })
        });
        console.log('✅ Fetch endpoint:', fetchResponse.status);

    } catch (error) {
        console.log('❌ Endpoint test failed:', error.message);
    }
}

// Test 2: Manual model fetch with LiteLLM key
async function testModelFetch() {
    console.log('2. Testing model fetch with provided key...');

    const testKey = 'sk-VljIf75Fng08lDSlI7MJ7Q';

    try {
        // First, we need to save the API key
        console.log('📝 Saving API key...');
        const saveResponse = await fetch('/api/keys', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name: 'LiteLLM',
                value: testKey,
                expiresAt: ''
            })
        });

        if (saveResponse.ok) {
            console.log('✅ API key saved');

            // Now try to fetch models
            console.log('🔄 Fetching models...');
            const fetchResponse = await fetch('/api/models/fetch', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ endpoint: 'LiteLLM' })
            });

            if (fetchResponse.ok) {
                const data = await fetchResponse.json();
                console.log('✅ Models fetched successfully!');
                console.log('📋 Available models:', data.models);
            } else {
                console.log('❌ Fetch failed:', fetchResponse.status, await fetchResponse.text());
            }
        } else {
            console.log('❌ Failed to save API key:', saveResponse.status);
        }

    } catch (error) {
        console.log('❌ Model fetch test failed:', error.message);
    }
}

// Test 3: Check if our frontend code is loaded
function testFrontendCode() {
    console.log('3. Checking if frontend modifications are loaded...');

    // Try to find our debug messages in the loaded scripts
    const scripts = document.querySelectorAll('script[src]');
    let foundOurCode = false;

    scripts.forEach(script => {
        if (script.src.includes('assets/') && !script.src.includes('workbox')) {
            // We can't directly check script content due to CORS, but we can check if it's loading
            console.log('📄 Script loaded:', script.src);
        }
    });

    // Try to call our functions if they exist
    if (typeof window !== 'undefined' && window.console) {
        console.log('✅ Console available - our code should be able to log here');
    }

    console.log('🔍 Look for these messages when entering API key:');
    console.log('   - "[Dynamic Model Fetch] Fetching models for endpoint: LiteLLM"');
    console.log('   - "[Dynamic Model Fetch] User logged in, scheduling auto-refresh"');
}

// Run all tests
async function runAllTests() {
    console.log('🚀 Starting Dynamic Model Fetching Tests\n');

    await testEndpoints();
    console.log('');

    await testModelFetch();
    console.log('');

    testFrontendCode();
    console.log('');

    console.log('🎯 Test complete! If you see model lists above, the backend is working!');
}

// Make it available globally
window.testDynamicModels = runAllTests;

// Auto-run the tests
console.log('💡 Run: testDynamicModels() to run the tests manually');
console.log('💡 Or the tests will run automatically in 3 seconds...\n');

// Auto-run after a short delay
setTimeout(runAllTests, 3000);

