// Simple test to manually trigger model fetching
console.log('🎯 Simple Model Fetch Test');

const jwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY4YzFjMzI5YjYzZmYyZmQ4YzgzNGY1YyIsInVzZXJuYW1lIjoiYWRtaW4xQHNrb29wc2lnYW5nZS5jb20iLCJwcm92aWRlciI6ImxvY2FsIiwiZW1haWwiOiJhZG1pbjFAc2tvb3BzaWdhbmdlLmNvbSIsImlhdCI6MTc1NzUzMzgzNSwiZXhwIjoxNzU3NTM0NzM1fQ.uCzd0jBDUmGt8Mq2jMMf1SRM3p8MWXVrZoUUs2Q0Rto';
const testKey = 'sk-VljIf75Fng08lDSlI7MJ7Q';

// LiteLLM configuration from librechat.yaml
const liteLLMConfig = {
    name: 'LiteLLM',
    apiKey: 'user_provided',
    baseURL: 'https://litellm.skoop.digital/v1',
    models: {
        default: ['gemini/gemini-2.0-flash-lite', 'openai/gpt-4o'],
        fetch: true
    }
};

async function simpleFetchTest() {
    console.log('🔑 Using JWT token for auth');
    console.log('🔧 Using LiteLLM config:', liteLLMConfig);

    try {
        // First save the API key
        console.log('💾 Saving API key...');
        const saveResp = await fetch('/api/keys', {
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

        console.log('Save status:', saveResp.status);

        if (saveResp.ok) {
            console.log('✅ API key saved');

            // Now try to manually fetch models using the LiteLLM API directly
            console.log('🔄 Fetching models from LiteLLM API...');

            try {
                const modelsResp = await fetch(`${liteLLMConfig.baseURL}/models`, {
                    headers: {
                        'Authorization': `Bearer ${testKey}`
                    }
                });

                console.log('LiteLLM API response status:', modelsResp.status);

                if (modelsResp.ok) {
                    const modelsData = await modelsResp.json();
                    console.log('🎉 SUCCESS! Models from LiteLLM:');
                    console.log(modelsData);

                    if (modelsData.data && Array.isArray(modelsData.data)) {
                        const modelIds = modelsData.data.map(m => m.id);
                        console.log('📋 Model IDs:', modelIds);
                        console.log('✅ LiteLLM integration is working perfectly!');
                    }
                } else {
                    console.log('❌ LiteLLM API failed:', modelsResp.status);
                    const errorText = await modelsResp.text();
                    console.log('Error:', errorText);
                }
            } catch (error) {
                console.log('❌ LiteLLM API call failed:', error.message);
            }

            // Also try our backend endpoint
            console.log('\n🔄 Testing our backend endpoint...');
            const backendResp = await fetch('/api/models/fetch', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${jwtToken}`
                },
                body: JSON.stringify({ endpoint: 'LiteLLM' })
            });

            console.log('Backend response status:', backendResp.status);

            if (backendResp.ok) {
                const backendData = await backendResp.json();
                console.log('🎉 SUCCESS! Backend working!');
                console.log('Models:', backendData.models);
            } else {
                console.log('❌ Backend failed:', backendResp.status);
                const errorText = await backendResp.text();
                console.log('Error:', errorText);
            }

        } else {
            console.log('❌ API key save failed:', saveResp.status);
            const errorText = await saveResp.text();
            console.log('Save error:', errorText);
        }

    } catch (error) {
        console.log('❌ Test failed:', error.message);
    }
}

simpleFetchTest();

