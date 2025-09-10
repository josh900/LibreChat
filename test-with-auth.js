// Test with proper authentication
console.log('🔐 Testing with Authentication');

// First, get the session cookie/token from browser storage
function getAuthHeaders() {
    // Try to get from cookies
    const cookies = document.cookie.split(';');
    const sessionCookie = cookies.find(cookie => cookie.trim().startsWith('connect.sid='));

    if (sessionCookie) {
        return { 'Cookie': sessionCookie.trim() };
    }

    // Try to get JWT from localStorage
    const token = localStorage.getItem('token') || localStorage.getItem('accessToken');
    if (token) {
        return { 'Authorization': `Bearer ${token}` };
    }

    console.log('❌ No authentication found. Please make sure you are logged in.');
    return null;
}

async function testWithAuth() {
    console.log('🔑 Getting authentication...');
    const authHeaders = getAuthHeaders();

    if (!authHeaders) {
        console.log('❌ Please login first and then run this test');
        return;
    }

    console.log('✅ Authentication found:', Object.keys(authHeaders)[0]);

    const testKey = 'sk-VljIf75Fng08lDSlI7MJ7Q';

    try {
        // Test 1: Save API key
        console.log('💾 Saving API key...');
        const saveResponse = await fetch('/api/keys', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...authHeaders
            },
            body: JSON.stringify({
                name: 'LiteLLM',
                value: testKey,
                expiresAt: ''
            })
        });

        if (saveResponse.ok) {
            console.log('✅ API key saved successfully');

            // Test 2: Fetch models
            console.log('🔄 Fetching models...');
            const fetchResponse = await fetch('/api/models/fetch', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    ...authHeaders
                },
                body: JSON.stringify({ endpoint: 'LiteLLM' })
            });

            if (fetchResponse.ok) {
                const data = await fetchResponse.json();
                console.log('🎉 SUCCESS! Dynamic model fetching is working!');
                console.log('📋 Available models:', data.models);
                console.log('🔢 Total models:', data.models?.length || 0);

                if (data.models && data.models.length > 0) {
                    console.log('✅ LiteLLM integration is working perfectly!');
                }
            } else {
                console.log('❌ Fetch failed:', fetchResponse.status);
                const errorText = await fetchResponse.text();
                console.log('Error details:', errorText);
            }
        } else {
            console.log('❌ API key save failed:', saveResponse.status);
            const errorText = await saveResponse.text();
            console.log('Save error:', errorText);
        }

    } catch (error) {
        console.log('❌ Test failed with error:', error.message);
    }
}

// Also test the basic endpoints
async function testEndpoints() {
    console.log('\n🔍 Testing basic endpoints...');
    const authHeaders = getAuthHeaders();

    if (!authHeaders) return;

    // Test models endpoint
    try {
        const modelsResp = await fetch('/api/models', {
            headers: authHeaders
        });
        console.log('📋 Models endpoint:', modelsResp.status);

        if (modelsResp.ok) {
            const modelsData = await modelsResp.json();
            console.log('📊 Models data received');
        }
    } catch (error) {
        console.log('❌ Models endpoint error:', error.message);
    }
}

console.log('🚀 Starting authenticated test...');
testWithAuth().then(() => {
    testEndpoints();
});

