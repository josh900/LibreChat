// Test with the provided JWT token
console.log('🔐 Testing with Provided JWT Token');

const jwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY4YzFjMzI5YjYzZmYyZmQ4YzgzNGY1YyIsInVzZXJuYW1lIjoiYWRtaW4xQHNrb29wc2lnYW5nZS5jb20iLCJwcm92aWRlciI6ImxvY2FsIiwiZW1haWwiOiJhZG1pbjFAc2tvb3BzaWdhbmdlLmNvbSIsImlhdCI6MTc1NzUzMzgzNSwiZXhwIjoxNzU3NTM0NzM1fQ.uCzd0jBDUmGt8Mq2jMMf1SRM3p8MWXVrZoUUs2Q0Rto';
const testKey = 'sk-VljIf75Fng08lDSlI7MJ7Q';

async function testWithJWT() {
    console.log('🔑 Using JWT token for authentication');

    try {
        // Test 1: Save API key
        console.log('💾 Saving API key...');
        const saveResponse = await fetch('/api/keys', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${jwtToken}`
            },
            body: JSON.stringify({
                name: 'LiteLLM',
                value: testKey,
                expiresAt: ''
            })
        });

        console.log('Save response status:', saveResponse.status);

        if (saveResponse.ok) {
            console.log('✅ API key saved successfully');
            const saveData = await saveResponse.json();
            console.log('Save response:', saveData);

            // Test 2: Fetch models
            console.log('🔄 Fetching models...');
            const fetchResponse = await fetch('/api/models/fetch', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${jwtToken}`
                },
                body: JSON.stringify({ endpoint: 'LiteLLM' })
            });

            console.log('Fetch response status:', fetchResponse.status);

            if (fetchResponse.ok) {
                const data = await fetchResponse.json();
                console.log('🎉 SUCCESS! Dynamic model fetching is working!');
                console.log('📋 Available models:', data.models);
                console.log('🔢 Total models:', data.models?.length || 0);

                if (data.models && data.models.length > 0) {
                    console.log('✅ LiteLLM integration is working perfectly!');
                    console.log('✅ Backend dynamic model fetching is FULLY FUNCTIONAL!');
                } else {
                    console.log('⚠️ No models returned - check LiteLLM server');
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
        console.log('Stack:', error.stack);
    }
}

// Also test the regular models endpoint
async function testModelsEndpoint() {
    console.log('\n📋 Testing models endpoint...');

    try {
        const modelsResponse = await fetch('/api/models', {
            headers: {
                'Authorization': `Bearer ${jwtToken}`
            }
        });

        console.log('Models response status:', modelsResponse.status);

        if (modelsResponse.ok) {
            const modelsData = await modelsResponse.json();
            console.log('✅ Models endpoint working');
            console.log('Available endpoints:', Object.keys(modelsData));
        } else {
            console.log('❌ Models endpoint failed');
        }
    } catch (error) {
        console.log('❌ Models endpoint error:', error.message);
    }
}

console.log('🚀 Starting JWT authenticated test...');
testWithJWT().then(() => {
    testModelsEndpoint();
});

