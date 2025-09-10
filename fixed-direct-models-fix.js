// Direct fix with proper JWT authentication: Modify the models endpoint to return fetched models immediately
console.log('🔧 Applying Direct Models Fix with Authentication');

const jwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY4YzFjMzI5YjYzZmYyZmQ4YzgzNGY1YyIsInVzZXJuYW1lIjoiYWRtaW4xQHNrb29wc2lnYW5nZS5jb20iLCJwcm92aWRlciI6ImxvY2FsIiwiZW1haWwiOiJhZG1pbjFAc2tvb3BzaWdhbmdlLmNvbSIsImlhdCI6MTc1NzUzODAzMSwiZXhwIjoxNzU3NTM4OTMxfQ.E3CEFBOu2b-yn_k-Tdbsib2Xzt_ARADFx8-EoktTYA0';

// Function to override the models fetching
function overrideModelsEndpoint() {
  console.log('📡 Overriding models endpoint...');

  // Store original fetch
  const originalFetch = window.fetch;

  // Override fetch for models endpoint
  window.fetch = function(url, options) {
    if (typeof url === 'string' && url === '/api/models') {
      console.log('🎯 Intercepted models request');

      // Add authorization header if not present
      const headers = options?.headers || {};
      if (!headers['Authorization']) {
        headers['Authorization'] = `Bearer ${jwtToken}`;
        options = { ...options, headers };
      }

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

            try {
              const fetchResponse = await originalFetch('/api/models/fetch', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': `Bearer ${jwtToken}`
                },
                body: JSON.stringify({ endpoint: 'LiteLLM' })
              });

              if (fetchResponse.ok) {
                const fetchData = await fetchResponse.json();
                console.log('✅ Fetched real models:', fetchData.models.length);

                // Update the response data
                data.LiteLLM = fetchData.models;
                console.log('🔄 Updated models response with real models');
              } else {
                console.error('❌ Fetch failed:', fetchResponse.status);
              }
            } catch (error) {
              console.error('❌ Failed to fetch real models:', error);
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

  console.log('✅ Models endpoint override applied with authentication');
}

// Apply the fix
overrideModelsEndpoint();

// Test the fix
setTimeout(async () => {
  console.log('🧪 Testing the fix with authentication...');

  try {
    const response = await fetch('/api/models', {
      headers: {
        'Authorization': `Bearer ${jwtToken}`
      }
    });
    const data = await response.json();

    console.log('📊 Models after fix:', {
      endpoints: Object.keys(data),
      liteLLMCount: data.LiteLLM ? data.LiteLLM.length : 0,
      first10: data.LiteLLM ? data.LiteLLM.slice(0, 10) : []
    });

    if (data.LiteLLM && data.LiteLLM.length > 2) {
      console.log('🎉 SUCCESS! Fix is working!');
      console.log('💡 Now refresh the page and check if models appear in the dropdown');
    } else {
      console.log('❌ Fix not working yet');
    }
  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}, 2000);
