// Comprehensive UI Fix: Intercept API calls AND force React updates
console.log('🔧 Applying Comprehensive UI Fix');

const jwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY4YzFjMzI5YjYzZmYyZmQ4YzgzNGY1YyIsInVzZXJuYW1lIjoiYWRtaW4xQHNrb29wc2lnYW5nZS5jb20iLCJwcm92aWRlciI6ImxvY2FsIiwiZW1haWwiOiJhZG1pbjFAc2tvb3BzaWdhbmdlLmNvbSIsImlhdCI6MTc1NzUzODAzMSwiZXhwIjoxNzU3NTM4OTMxfQ.E3CEFBOu2b-yn_k-Tdbsib2Xzt_ARADFx8-EoktTYA0';

// Function to force React component updates
function forceReactUpdates() {
  console.log('🔄 Forcing React component updates...');

  // Try to find and update React components
  const reactRoots = [];

  // Search for React root elements
  function findReactRoots(element) {
    if (element && element._reactInternalInstance) {
      reactRoots.push(element);
    }

    if (element && element.children) {
      for (let i = 0; i < element.children.length; i++) {
        findReactRoots(element.children[i]);
      }
    }
  }

  findReactRoots(document.body);
  console.log('📊 Found React roots:', reactRoots.length);

  // Force re-renders by triggering DOM events
  const events = ['click', 'focus', 'blur', 'input', 'change'];

  // Trigger events on form elements that might be related to model selection
  const formElements = document.querySelectorAll('select, input, button');
  formElements.forEach(element => {
    if (element.id && element.id.includes('model')) {
      console.log('🎯 Triggering update on model-related element:', element.id);
      events.forEach(eventType => {
        try {
          element.dispatchEvent(new Event(eventType, { bubbles: true }));
        } catch (e) {
          // Ignore event dispatch errors
        }
      });
    }
  });

  // Force a global re-render by triggering window events
  window.dispatchEvent(new Event('resize'));
  window.dispatchEvent(new Event('scroll'));

  console.log('✅ React update events triggered');
}

// Enhanced models endpoint override
function overrideModelsEndpoint() {
  console.log('📡 Setting up enhanced models endpoint override...');

  const originalFetch = window.fetch;

  window.fetch = function(url, options) {
    if (typeof url === 'string' && url === '/api/models') {
      console.log('🎯 Intercepted models request');

      // Add authorization header
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

          // If LiteLLM only has 2 models, fetch the real ones
          if (data.LiteLLM && data.LiteLLM.length === 2) {
            console.log('🔄 Fetching real models...');

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

                data.LiteLLM = fetchData.models;
                console.log('🔄 Updated models response with real models');

                // Force React updates after successful model fetch
                setTimeout(() => {
                  console.log('🔄 Triggering React updates after model fetch...');
                  forceReactUpdates();

                  // Also try to manually update any model selection components
                  updateModelComponents(fetchData.models);
                }, 100);

              } else {
                console.error('❌ Fetch failed:', fetchResponse.status);
              }
            } catch (error) {
              console.error('❌ Failed to fetch real models:', error);
            }
          }

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

  console.log('✅ Enhanced models endpoint override applied');
}

// Function to manually update model selection components
function updateModelComponents(models) {
  console.log('🎯 Attempting to update model selection components...');

  // Find model selection dropdowns
  const selects = document.querySelectorAll('select');
  selects.forEach(select => {
    if (select.id && (select.id.includes('model') || select.id.includes('endpoint'))) {
      console.log('📝 Found model select element:', select.id);

      // Clear existing options
      select.innerHTML = '';

      // Add the fetched models
      models.slice(0, 50).forEach(model => { // Limit to first 50 for performance
        const option = document.createElement('option');
        option.value = model;
        option.textContent = model;
        select.appendChild(option);
      });

      console.log('✅ Updated select element with', Math.min(models.length, 50), 'models');

      // Trigger change event
      select.dispatchEvent(new Event('change', { bubbles: true }));
    }
  });

  // Also try to find any div elements that might contain model lists
  const modelContainers = document.querySelectorAll('[role="listbox"], [data-testid*="model"], .model-list, .endpoint-list');
  modelContainers.forEach(container => {
    console.log('🎯 Found model container:', container.className || container.id);

    // Force a re-render by adding/removing a class
    container.classList.add('models-updated');
    setTimeout(() => container.classList.remove('models-updated'), 100);
  });
}

// Function to periodically check and update models
function startModelUpdater() {
  console.log('⏰ Starting periodic model updater...');

  const checkInterval = setInterval(async () => {
    try {
      console.log('🔍 Periodic model check...');

      const response = await fetch('/api/models', {
        headers: { 'Authorization': `Bearer ${jwtToken}` }
      });

      if (response.ok) {
        const data = await response.json();
        const liteLLMCount = data.LiteLLM ? data.LiteLLM.length : 0;

        if (liteLLMCount > 2) {
          console.log('✅ Models are updated in API (', liteLLMCount, '), forcing UI refresh...');
          forceReactUpdates();
          updateModelComponents(data.LiteLLM);
        } else {
          console.log('⚠️ Models still showing defaults (', liteLLMCount, '), keeping updater active...');
        }
      }
    } catch (error) {
      console.error('❌ Periodic check failed:', error);
    }
  }, 5000); // Check every 5 seconds

  // Stop after 2 minutes
  setTimeout(() => {
    console.log('⏰ Stopping periodic model updater');
    clearInterval(checkInterval);
  }, 120000);

  return checkInterval;
}

// Apply all fixes
console.log('🚀 Applying comprehensive fixes...');
overrideModelsEndpoint();

// Start periodic updater
const updaterInterval = startModelUpdater();

// Test the comprehensive fix
setTimeout(async () => {
  console.log('🧪 Testing comprehensive fix...');

  try {
    const response = await fetch('/api/models', {
      headers: { 'Authorization': `Bearer ${jwtToken}` }
    });
    const data = await response.json();

    console.log('📊 Final test results:', {
      endpoints: Object.keys(data),
      liteLLMCount: data.LiteLLM ? data.LiteLLM.length : 0,
      first10: data.LiteLLM ? data.LiteLLM.slice(0, 10) : []
    });

    if (data.LiteLLM && data.LiteLLM.length > 2) {
      console.log('🎉 COMPREHENSIVE FIX SUCCESS!');
      console.log('💡 Models should now be visible in the dropdown');
      console.log('💡 Periodic updater is running for 2 minutes');
    } else {
      console.log('❌ Fix not working yet');
    }
  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}, 3000);

// Also trigger immediate updates
setTimeout(() => {
  console.log('🔄 Triggering immediate React updates...');
  forceReactUpdates();
}, 1000);
