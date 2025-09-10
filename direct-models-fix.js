// Direct fix: Modify the models endpoint to return fetched models immediately
// This bypasses the React Query cache update issue

console.log('🔧 Applying Direct Models Fix');

// Function to override the models fetching
function overrideModelsEndpoint() {
  console.log('📡 Overriding models endpoint...');

  // Store original fetch
  const originalFetch = window.fetch;

  // Override fetch for models endpoint
  window.fetch = function(url, options) {
    if (typeof url === 'string' && url === '/api/models') {
      console.log('🎯 Intercepted models request');

      return originalFetch(url, options).then(async response => {
        if (response.ok) {
          const data = await response.clone().json();
          console.log('📊 Original models data:', {
            endpoints: Object.keys(data),
            liteLLMCount: data.LiteLLM ? data.LiteLLM.length : 0
          });

          // If LiteLLM only has 2 models, try to fetch the real models
          if (data.LiteLLM && data.LiteLLM.length === 2) {
            console.log('🔄 LiteLLM has only default models, fetching real ones...');

            // Get JWT token
            const token = localStorage.getItem('token');
            if (token) {
              try {
                const fetchResponse = await originalFetch('/api/models/fetch', {
                  method: 'POST',
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                  },
                  body: JSON.stringify({ endpoint: 'LiteLLM' })
                });

                if (fetchResponse.ok) {
                  const fetchData = await fetchResponse.json();
                  console.log('✅ Fetched real models:', fetchData.models.length);

                  // Update the response data
                  data.LiteLLM = fetchData.models;
                  console.log('🔄 Updated models response with real models');
                }
              } catch (error) {
                console.error('❌ Failed to fetch real models:', error);
              }
            }
          }

          // Return modified response
          return new Response(JSON.stringify(data), {
            status: response.status,
            statusText: response.statusText,
            headers: response.headers
          });
        }

        return response;
      });
    }

    return originalFetch.apply(this, arguments);
  };

  console.log('✅ Models endpoint override applied');
}

// Apply the fix
overrideModelsEndpoint();

// Test the fix
setTimeout(async () => {
  console.log('🧪 Testing the fix...');

  try {
    const response = await fetch('/api/models');
    const data = await response.json();

    console.log('📊 Models after fix:', {
      endpoints: Object.keys(data),
      liteLLMCount: data.LiteLLM ? data.LiteLLM.length : 0,
      first10: data.LiteLLM ? data.LiteLLM.slice(0, 10) : []
    });

    if (data.LiteLLM && data.LiteLLM.length > 2) {
      console.log('🎉 SUCCESS! Fix is working!');
    } else {
      console.log('❌ Fix not working yet');
    }
  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}, 2000);
