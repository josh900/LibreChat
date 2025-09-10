// Debug test to check what configuration is available
console.log('🔍 Debugging Configuration Access');

const jwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY4YzFjMzI5YjYzZmYyZmQ4YzgzNGY1YyIsInVzZXJuYW1lIjoiYWRtaW4xQHNrb29wc2lnYW5nZS5jb20iLCJwcm92aWRlciI6ImxvY2FsIiwiZW1haWwiOiJhZG1pbjFAc2tvb3BzaWdhbmdlLmNvbSIsImlhdCI6MTc1NzUzMzgzNSwiZXhwIjoxNzU3NTM0NzM1fQ.uCzd0jBDUmGt8Mq2jMMf1SRM3p8MWXVrZoUUs2Q0Rto';

async function testConfigAccess() {
    console.log('📋 Testing configuration access...');

    try {
        // Test 1: Check if we can access the models endpoint
        const modelsResp = await fetch('/api/models', {
            headers: { 'Authorization': `Bearer ${jwtToken}` }
        });

        if (modelsResp.ok) {
            const modelsData = await modelsResp.json();
            console.log('✅ Models endpoint working');
            console.log('Available endpoints:', Object.keys(modelsData));

            // Check if LiteLLM is in the models
            if (modelsData.LiteLLM) {
                console.log('✅ LiteLLM found in models:', modelsData.LiteLLM);
            } else {
                console.log('❌ LiteLLM not found in models');
                console.log('Available endpoints:', Object.keys(modelsData));
            }
        } else {
            console.log('❌ Models endpoint failed:', modelsResp.status);
        }

        // Test 2: Try to get configuration
        console.log('\n🔧 Testing configuration endpoints...');

        // Try to get config endpoint
        const configResp = await fetch('/api/config', {
            headers: { 'Authorization': `Bearer ${jwtToken}` }
        });

        if (configResp.ok) {
            const configData = await configResp.json();
            console.log('✅ Config endpoint working');
            console.log('Config keys:', Object.keys(configData || {}));

            if (configData.endpoints) {
                console.log('✅ Endpoints found in config');
                if (configData.endpoints.custom) {
                    console.log('✅ Custom endpoints found');
                    const liteLLM = configData.endpoints.custom.find(e => e.name === 'LiteLLM');
                    if (liteLLM) {
                        console.log('✅ LiteLLM config found:', liteLLM);
                    } else {
                        console.log('❌ LiteLLM config not found in custom endpoints');
                        console.log('Available custom endpoints:', configData.endpoints.custom.map(e => e.name));
                    }
                } else {
                    console.log('❌ No custom endpoints found');
                }
            } else {
                console.log('❌ No endpoints found in config');
            }
        } else {
            console.log('❌ Config endpoint failed:', configResp.status);
        }

    } catch (error) {
        console.log('❌ Test failed:', error.message);
    }
}

testConfigAccess();

