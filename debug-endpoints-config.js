// Debug what the endpoints config actually looks like
console.log('🔍 Debugging Endpoints Configuration');

// Test 1: Check the raw endpoints config
fetch('/api/config')
  .then(res => res.json())
  .then(config => {
    console.log('📋 Raw config:', config);
    console.log('🔍 Endpoints in config:', config.endpoints);
  })
  .catch(err => console.error('❌ Config fetch failed:', err));

// Test 2: Check what the endpoints query returns
setTimeout(() => {
  console.log('🔍 Checking endpoints query...');
  if (window.librechatDataProvider) {
    const { useGetEndpointsQuery } = window.librechatDataProvider.reactQuery;
    console.log('✅ Data provider available');
    console.log('🔍 useGetEndpointsQuery:', useGetEndpointsQuery);
  } else {
    console.log('❌ Data provider not available');
  }
}, 2000);

// Test 3: Manual endpoint config check
setTimeout(() => {
  console.log('🔍 Manual endpoints config check...');
  const endpointsConfig = {
    LiteLLM: {
      name: 'LiteLLM',
      apiKey: 'user_provided',
      baseURL: 'https://litellm.skoop.digital/v1',
      models: {
        fetch: true,
        default: ['gemini/gemini-2.0-flash-lite', 'openai/gpt-4o']
      }
    }
  };

  console.log('📊 Manual endpoints config:', endpointsConfig);

  const userProvidedEndpoints = Object.entries(endpointsConfig)
    .filter(([_, config]) => {
      console.log('🔍 Checking endpoint:', _, 'config:', config);
      const isUserProvided = config?.apiKey === 'user_provided';
      const hasFetch = config?.models?.fetch;
      console.log('  - apiKey check:', config?.apiKey, '=== user_provided:', isUserProvided);
      console.log('  - fetch check:', config?.models?.fetch, '=== true:', hasFetch);
      return isUserProvided && hasFetch;
    })
    .map(([endpoint]) => endpoint);

  console.log('✅ Filtered user-provided endpoints:', userProvidedEndpoints);
}, 1000);
