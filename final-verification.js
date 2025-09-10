// Final verification that everything is working
console.log('🎯 FINAL VERIFICATION TEST');

const jwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY4YzFjMzI5YjYzZmYyZmQ4YzgzNGY1YyIsInVzZXJuYW1lIjoiYWRtaW4xQHNrb29wc2lnYW5nZS5jb20iLCJwcm92aWRlciI6ImxvY2FsIiwiZW1haWwiOiJhZG1pbjFAc2tvb3BzaWdhbmdlLmNvbSIsImlhdCI6MTc1NzUzODAzMSwiZXhwIjoxNzU3NTM4OTMxfQ.E3CEFBOu2b-yn_k-Tdbsib2Xzt_ARADFx8-EoktTYA0';

async function finalTest() {
    console.log('1️⃣ Testing API key save...');

    const saveResp = await fetch('/api/keys', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${jwtToken}`
        },
        body: JSON.stringify({
            name: 'LiteLLM',
            value: 'sk-VljIf75Fng08lDSlI7MJ7Q',
            expiresAt: ''
        })
    });

    if (saveResp.ok) {
        console.log('✅ API key saved');

        console.log('2️⃣ Testing backend model fetch...');

        const fetchResp = await fetch('/api/models/fetch', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${jwtToken}`
            },
            body: JSON.stringify({ endpoint: 'LiteLLM' })
        });

        if (fetchResp.ok) {
            const fetchData = await fetchResp.json();
            console.log('✅ Backend working! Fetched:', fetchData.models.length, 'models');

            console.log('3️⃣ Testing UI models cache...');

            const modelsResp = await fetch('/api/models', {
                headers: { 'Authorization': `Bearer ${jwtToken}` }
            });

            if (modelsResp.ok) {
                const modelsData = await modelsResp.json();
                const liteLLMModels = modelsData.LiteLLM || [];
                console.log('📊 UI shows:', liteLLMModels.length, 'LiteLLM models');

                if (liteLLMModels.length > 2) {
                    console.log('🎉 SUCCESS! Models are in UI cache!');
                    console.log('First 10 models:', liteLLMModels.slice(0, 10));

                    console.log('4️⃣ Checking if models appear in dropdown...');

                    // Check if there are any select elements with models
                    const selects = document.querySelectorAll('select');
                    let foundModels = false;

                    selects.forEach(select => {
                        if (select.options.length > 10) { // More than just default options
                            console.log('✅ Found populated dropdown with', select.options.length, 'options');
                            foundModels = true;
                        }
                    });

                    if (foundModels) {
                        console.log('🎉 SUCCESS! Models are visible in dropdowns!');
                    } else {
                        console.log('⚠️ Models in cache but not in dropdowns yet');
                        console.log('💡 Try clicking on the model selection dropdown to refresh it');
                    }

                } else {
                    console.log('❌ Models not in UI cache');
                    console.log('Backend returned:', fetchData.models.length, 'models');
                    console.log('UI cache has:', liteLLMModels.length, 'models');
                }
            } else {
                console.log('❌ Models endpoint failed');
            }

        } else {
            console.log('❌ Backend fetch failed:', fetchResp.status);
        }

    } else {
        console.log('❌ API key save failed:', saveResp.status);
    }
}

// Run the final test
finalTest();
