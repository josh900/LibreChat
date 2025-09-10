#!/bin/bash

echo "🔧 Fixing Build Issues for Dynamic Model Fetching"

# Fix duplicate functions in data-service.ts
echo "1. Fixing duplicate functions in data-service.ts..."
docker exec LibreChat sed -i '/export const fetchUserModels = async (payload: { endpoint: string }): Promise<{ endpoint: string; models: string\[\]; tokenConfig\?: any }> => {/,+3d' /app/packages/data-provider/src/data-service.ts

# Keep only one instance
docker exec LibreChat sed -i '1,/export const fetchUserModels = async (payload: { endpoint: string }): Promise<{ endpoint: string; models: string\[\]; tokenConfig\?: any }> => {/!d' /app/packages/data-provider/src/data-service.ts

# Add the missing endpoint to api-endpoints.ts
echo "2. Adding missing fetchUserModels endpoint..."
docker exec LibreChat bash -c "echo -e '\n// Dynamic model fetching\nexport const fetchUserModels = () => \`\${BASE_URL}/api/models/fetch\`;' >> /app/packages/data-provider/src/api-endpoints.ts"

# Verify the fixes
echo "3. Verifying fixes..."
echo "Checking data-service.ts for duplicates:"
docker exec LibreChat grep -n "fetchUserModels" /app/packages/data-provider/src/data-service.ts

echo "Checking api-endpoints.ts for endpoint:"
docker exec LibreChat grep -n "fetchUserModels" /app/packages/data-provider/src/api-endpoints.ts

echo "4. Attempting to build the frontend..."
docker exec LibreChat npm run build:data-provider

if [ $? -eq 0 ]; then
    echo "✅ Data provider build successful!"
    echo "5. Building full frontend..."
    docker exec LibreChat npm run frontend
    if [ $? -eq 0 ]; then
        echo "✅ Frontend build successful!"
        echo "6. Restarting containers..."
        docker compose restart
        echo "🎉 All fixes applied! The dynamic model fetching should now work permanently."
    else
        echo "❌ Frontend build failed"
    fi
else
    echo "❌ Data provider build failed"
fi
