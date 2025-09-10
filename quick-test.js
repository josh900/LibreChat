// Quick test for backend dynamic model fetching
// Run this in browser console after logging into LibreChat

console.log('🧪 Quick Backend Test for Dynamic Models');

// Test LiteLLM API key
const testKey = 'sk-VljIf75Fng08lDSlI7MJ7Q';

async function quickTest() {
    console.log('🔑 Testing with LiteLLM key:', testKey.substring(0, 10) + '...');

    try {
        // Save the key
        console.log('💾 Saving API key...');
        const saveResp = await fetch('/api/keys', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({name: 'LiteLLM', value: testKey, expiresAt: ''})
        });

        if (saveResp.ok) {
            console.log('✅ Key saved');

            // Fetch models
            console.log('🔄 Fetching models...');
            const fetchResp = await fetch('/api/models/fetch', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({endpoint: 'LiteLLM'})
            });

            if (fetchResp.ok) {
                const data = await fetchResp.json();
                console.log('🎉 SUCCESS! Models fetched:');
                console.log(data.models);
                console.log('✅ Backend dynamic model fetching is WORKING!');
            } else {
                console.log('❌ Fetch failed:', fetchResp.status);
                console.log('Response:', await fetchResp.text());
            }
        } else {
            console.log('❌ Key save failed:', saveResp.status);
        }
    } catch (error) {
        console.log('❌ Test failed:', error.message);
    }
}

quickTest();

