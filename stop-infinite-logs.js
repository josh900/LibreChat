// Stop the infinite logging from the comprehensive fix
console.log('🛑 Stopping Infinite Logging');

// Stop all intervals that might be running
if (window.modelUpdaterInterval) {
  clearInterval(window.modelUpdaterInterval);
  console.log('✅ Stopped model updater interval');
}

// Stop any other potential intervals
for (let i = 1; i < 10000; i++) {
  try {
    clearInterval(i);
  } catch (e) {
    // Ignore errors
  }
}

console.log('✅ Cleared all intervals');
console.log('✅ Infinite logging stopped');

// Optional: Reset fetch to original
if (window.originalFetch) {
  window.fetch = window.originalFetch;
  console.log('✅ Restored original fetch function');
}

console.log('🎉 All fixes stopped. You can now test normally.');
