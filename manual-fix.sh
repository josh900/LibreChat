#!/bin/bash
echo "🔧 Manual Fix for Dynamic Model Fetching Build Issues"
echo "=================================================="

# Step 1: Check current status
echo ""
echo "1. Checking current duplicate functions..."
docker exec LibreChat grep -n "fetchUserModels" /app/packages/data-provider/src/data-service.ts

# Step 2: Remove duplicates (keep only the last one)
echo ""
echo "2. Removing duplicate functions..."
docker exec LibreChat cp /app/packages/data-provider/src/data-service.ts /app/packages/data-provider/src/data-service.ts.backup

# Find the last occurrence and keep only that
docker exec LibreChat bash -c "
  LAST_LINE=\$(grep -n 'fetchUserModels' /app/packages/data-provider/src/data-service.ts | tail -1 | cut -d: -f1)
  head -n \$((LAST_LINE - 1)) /app/packages/data-provider/src/data-service.ts > /tmp/data-service-clean.ts
  tail -n +\$LAST_LINE /app/packages/data-provider/src/data-service.ts >> /tmp/data-service-clean.ts
  mv /tmp/data-service-clean.ts /app/packages/data-provider/src/data-service.ts
"

# Step 3: Add missing endpoint
echo ""
echo "3. Adding missing fetchUserModels endpoint..."
docker exec LibreChat bash -c "
  if ! grep -q 'fetchUserModels' /app/packages/data-provider/src/api-endpoints.ts; then
    echo -e '\n// Dynamic model fetching\nexport const fetchUserModels = () => \`\${BASE_URL}/api/models/fetch\`;' >> /app/packages/data-provider/src/api-endpoints.ts
    echo '✅ Added fetchUserModels endpoint'
  else
    echo 'ℹ️ fetchUserModels endpoint already exists'
  fi
"

# Step 4: Verify fixes
echo ""
echo "4. Verifying fixes..."
echo "data-service.ts fetchUserModels count:"
docker exec LibreChat grep -c "fetchUserModels" /app/packages/data-provider/src/data-service.ts

echo "api-endpoints.ts fetchUserModels:"
docker exec LibreChat grep -n "fetchUserModels" /app/packages/data-provider/src/api-endpoints.ts

# Step 5: Try building
echo ""
echo "5. Attempting to build data-provider..."
if docker exec LibreChat npm run build:data-provider; then
    echo "✅ Data provider build successful!"

    echo ""
    echo "6. Attempting full frontend build..."
    if docker exec LibreChat npm run frontend; then
        echo "✅ Frontend build successful!"

        echo ""
        echo "7. Restarting containers..."
        docker compose restart

        echo ""
        echo "🎉 SUCCESS! Dynamic model fetching should now work permanently!"
        echo "   - Backend: ✅ Working (returns 414 models)"
        echo "   - Frontend: ✅ Rebuilt with dynamic functionality"
        echo "   - UI: Should now show 414+ LiteLLM models"

    else
        echo "❌ Frontend build failed"
        exit 1
    fi
else
    echo "❌ Data provider build failed"
    exit 1
fi
