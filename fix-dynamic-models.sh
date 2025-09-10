#!/bin/bash

# Fix script for dynamic model fetching - run this after post-install-dynamic-models.sh fails
echo "🔧 Fixing dynamic model fetching installation..."

# Check if we're in the right directory
if [ ! -f "librechat.yaml" ] || [ ! -d "api" ] || [ ! -d "client" ]; then
    echo "❌ Please run this script from the LibreChat root directory"
    exit 1
fi

echo "✅ Running from LibreChat root directory"

# Function to backup a file
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "✅ Backed up $file"
    fi
}

# Complete step 6 (react-query-service.ts) that failed
echo "🔄 Completing step 6: react-query-service.ts..."
if ! grep -q "useFetchUserModelsMutation" "packages/data-provider/src/react-query/react-query-service.ts"; then
    backup_file "packages/data-provider/src/react-query/react-query-service.ts"
    cat >> packages/data-provider/src/react-query/react-query-service.ts << 'EOF'

export const useFetchUserModelsMutation = (): UseMutationResult<
  { endpoint: string; models: string[]; tokenConfig?: any },
  unknown,
  { endpoint: string },
  unknown
> => {
  const queryClient = useQueryClient();
  return useMutation((payload: { endpoint: string }) => dataService.fetchUserModels(payload), {
    onSuccess: (data, variables) => {
      // Update the models cache with the newly fetched models
      queryClient.setQueryData([QueryKeys.models], (oldData: t.TModelsConfig | undefined) => {
        if (!oldData) {
          return oldData;
        }
        return {
          ...oldData,
          [variables.endpoint]: data.models,
        };
      });
    },
  });
};
EOF
    echo "✅ Added useFetchUserModelsMutation to react-query-service.ts"
else
    echo "ℹ️  useFetchUserModelsMutation already exists in react-query-service.ts"
fi

# Check if all files were created successfully
echo ""
echo "🔍 Verifying installation..."

files_to_check=(
    "api/server/services/Config/loadConfigModels.js"
    "api/server/routes/models.js"
    "api/server/controllers/ModelController.js"
    "packages/data-provider/src/api-endpoints.ts"
    "packages/data-provider/src/data-service.ts"
    "packages/data-provider/src/react-query/react-query-service.ts"
    "client/src/hooks/Input/useUserKey.ts"
    "client/src/routes/Root.tsx"
    "client/src/hooks/Input/useAutoModelRefresh.ts"
)

all_good=true
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        all_good=false
    fi
done

if [ "$all_good" = true ]; then
    echo ""
    echo "🎉 SUCCESS! Dynamic model fetching has been successfully installed!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Rebuild your LibreChat containers:"
    echo "   docker compose down"
    echo "   docker compose up --build -d"
    echo ""
    echo "2. Configure your librechat.yaml with:"
    echo "   endpoints:"
    echo "     custom:"
    echo "       - name: \"LiteLLM\""
    echo "         apiKey: \"user_provided\""
    echo "         baseURL: \"https://your-litellm-server.com/v1\""
    echo "         models:"
    echo "           default: [\"gemini/gemini-2.0-flash-lite\"]"
    echo "           fetch: true"
    echo ""
    echo "3. Users can now enter their API keys and see their personal models!"
else
    echo ""
    echo "❌ Some files are still missing. Please check the output above."
fi
