# Dynamic Model Fetching for User-Provided API Keys

This solution enables LibreChat to dynamically fetch available models from your LiteLLM server (or any OpenAI-compatible API) when users provide their own API keys for custom endpoints.

## Problem

By default, LibreChat only fetches models during Docker setup when using system-provided API keys. When users provide their own API keys for custom endpoints (like LiteLLM), the models are not fetched dynamically, resulting in users only seeing the default models specified in the configuration.

## Solution Overview

This implementation adds:

1. **Dynamic Model Fetching**: Models are fetched when users provide their API keys
2. **User-Specific Caching**: Each user's models are cached separately based on their API key
3. **Automatic Updates**: Models are refreshed when users update their API keys
4. **Post-Install Scripts**: Automated installation scripts for easy deployment

## Files Modified

### Backend Changes
- `api/server/services/Config/loadConfigModels.js` - Modified to handle user-provided keys
- `api/server/routes/models.js` - Added new `/fetch` endpoint
- `api/server/controllers/ModelController.js` - Added `fetchUserModelsController`

### Data Provider Changes
- `packages/data-provider/src/api-endpoints.ts` - Added `fetchUserModels` endpoint
- `packages/data-provider/src/data-service.ts` - Added `fetchUserModels` function
- `packages/data-provider/src/react-query/react-query-service.ts` - Added `useFetchUserModelsMutation`

### Frontend Changes
- `client/src/hooks/Input/useUserKey.ts` - Modified to fetch models after saving API key

## Installation

### Option 1: Automated Installation with Official LibreChat (Recommended)

1. **Install LibreChat using the official method:**
```bash
# Use the official LibreChat installation
git clone https://github.com/danny-avila/LibreChat.git
cd LibreChat
# Follow official installation instructions (install-ec2.sh, docker-compose, etc.)
```

2. **Apply dynamic model fetching after installation:**
```bash
# After your LibreChat installation is complete, run:
./post-install-dynamic-models.sh

# For Windows users:
post-install-dynamic-models.bat
```

**Note**: The script will automatically backup your existing files and apply all necessary changes.

### Option 2: Docker Integration

Add the post-install script to your Docker build:

```dockerfile
# In your Dockerfile, after installing LibreChat:
COPY post-install-dynamic-models.sh /app/
RUN chmod +x /app/post-install-dynamic-models.sh && /app/post-install-dynamic-models.sh
```

### Option 3: Manual Installation

Apply the changes manually by copying the modified files from this repository into your LibreChat instance.

## Configuration

Your `librechat.yaml` configuration should look like this:

```yaml
endpoints:
  custom:
    - name: "LiteLLM"
      apiKey: "user_provided"
      baseURL: "https://your-litellm-server.com/v1"
      models:
        default: ["gemini/gemini-2.0-flash-lite", "openai/gpt-4o"]
        fetch: true
      titleConvo: true
      titleModel: "gemini/gemini-2.0-flash-lite"
      summarize: false
      summaryModel: "gemini/gemini-2.0-flash-lite"
      forcePrompt: false
      modelDisplayLabel: "LiteLLM"
```

**Important**: The `fetch: true` setting is crucial - it enables dynamic model fetching for this endpoint.

## How It Works

1. **User Provides API Key**: When a user enters their API key through the LibreChat interface
2. **Automatic Model Fetching**: The system automatically calls your LiteLLM server's `/models` endpoint
3. **Dynamic Model List**: The available models for that specific user's API key are fetched and displayed
4. **Caching**: Models are cached per user to improve performance
5. **Cache Invalidation**: When users update their API key, the cache is invalidated and models are refetched

## API Flow

```
User enters API key → useUserKey hook → Update user key → Fetch models → Update cache → Display models
```

### Auto-Refresh Flow

The system now automatically refreshes models in these scenarios:

1. **On Login**: When a user logs in, their models are automatically fetched
2. **On Page Refresh**: Models are refreshed when the page loads
3. **On Tab Switch**: When returning to the tab after 5+ minutes, models refresh
4. **On Key Update**: When users change their API keys, models are refetched

## Benefits

- **Per-User Models**: Each user sees only the models available to their API key
- **Real-time Updates**: Models are fetched immediately when keys are provided
- **Performance**: Intelligent caching reduces API calls
- **Compatibility**: Works with any OpenAI-compatible API (LiteLLM, OpenRouter, etc.)
- **Security**: User keys are handled securely and never exposed

## Troubleshooting

### Models not appearing after entering API key

1. Check that `fetch: true` is set in your endpoint configuration
2. Verify your LiteLLM server is accessible and returns models correctly
3. Check browser console for any error messages
4. Ensure the API key has permission to access the `/models` endpoint

### API errors when fetching models

1. Verify your LiteLLM server URL is correct
2. Check that the API key format is accepted by your LiteLLM server
3. Ensure CORS is properly configured if running in a browser environment

### Performance issues

- Models are cached for 24 hours by default
- The cache can be cleared by refreshing the page or updating the API key

## Testing

To test the implementation:

1. Set up your LibreChat with the modified code
2. Configure a custom endpoint with `fetch: true`
3. Have a user enter their API key
4. Verify that the model dropdown shows models from their API key
5. Test with different API keys to ensure user isolation

## Docker Integration

To automatically apply these changes in your Docker build, add this to your `Dockerfile`:

```dockerfile
# After copying source code
COPY post-install-dynamic-models.sh /app/
RUN chmod +x /app/post-install-dynamic-models.sh

# After installing dependencies but before starting the app
RUN /app/post-install-dynamic-models.sh
```

## Security Considerations

- API keys are stored securely using LibreChat's existing key management
- Model fetching only occurs over HTTPS
- User keys are never logged or exposed in error messages
- Each user's models are isolated and cached separately

## Compatibility

This solution is compatible with:
- LiteLLM servers
- OpenRouter
- Any OpenAI-compatible API that supports the `/models` endpoint
- All LibreChat deployment methods (Docker, native, etc.)

## Support

If you encounter issues:

1. Check the browser console for JavaScript errors
2. Verify your LiteLLM server logs for API call errors
3. Ensure your `librechat.yaml` configuration is correct
4. Test your LiteLLM server's `/models` endpoint directly

## Future Enhancements

Potential improvements:
- Background model refreshing
- Model health checking
- Fallback to default models on API errors
- Support for custom model filtering
- Integration with model marketplace features
