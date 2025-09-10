// Debug script to test cache updates
console.log('🔍 Testing React Query Cache Updates');

// Test 1: Check if we can access the query client
if (window.librechatDataProvider && window.librechatDataProvider.reactQuery) {
  console.log('✅ Data provider available');

  // Test 2: Try to manually update the cache
  const { QueryKeys } = window.librechatDataProvider;
  console.log('📋 QueryKeys:', QueryKeys);

  // Get the current models
  const currentModels = {
    LiteLLM: ['gemini/gemini-2.0-flash-lite', 'openai/gpt-4o']
  };
  console.log('📊 Current models:', currentModels);

  // Try to update with fetched models
  const fetchedModels = Array.from({length: 414}, (_, i) => `model-${i + 1}`);
  const updatedModels = {
    ...currentModels,
    LiteLLM: fetchedModels
  };

  console.log('🔄 Updated models:', {
    LiteLLM: updatedModels.LiteLLM.length + ' models',
    first10: updatedModels.LiteLLM.slice(0, 10)
  });

  // Test 3: Try to access React Query directly
  if (window.ReactQueryClient) {
    console.log('✅ React Query client available');

    try {
      // Try to set the query data
      window.ReactQueryClient.setQueryData([QueryKeys.models], updatedModels);
      console.log('✅ Cache updated manually');

      // Try to invalidate
      window.ReactQueryClient.invalidateQueries([QueryKeys.models]);
      console.log('✅ Cache invalidated');

    } catch (error) {
      console.error('❌ Cache update failed:', error);
    }
  } else {
    console.log('❌ React Query client not available');
    console.log('Available window properties:', Object.keys(window).filter(key => key.toLowerCase().includes('query') || key.toLowerCase().includes('react')));
  }

} else {
  console.log('❌ Data provider not available');
  console.log('Available window properties:', Object.keys(window).filter(key => key.toLowerCase().includes('libre') || key.toLowerCase().includes('data')));
}

// Test 4: Check current models endpoint
setTimeout(async () => {
  console.log('🔍 Testing models endpoint...');
  try {
    const response = await fetch('/api/models');
    const data = await response.json();
    console.log('📊 Models from endpoint:', {
      endpoints: Object.keys(data),
      liteLLMCount: data.LiteLLM ? data.LiteLLM.length : 0
    });
  } catch (error) {
    console.error('❌ Models endpoint failed:', error);
  }
}, 1000);
