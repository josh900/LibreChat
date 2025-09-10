#!/bin/bash

echo "🔧 Restoring client dist from official Docker image"

# Pull the official image to get the pre-built client
echo "Pulling official LibreChat image..."
docker pull ghcr.io/danny-avila/librechat-dev:latest

# Create a temporary container to extract the dist folder
echo "Extracting client dist folder..."
docker create --name temp-librechat ghcr.io/danny-avila/librechat-dev:latest

# Copy the dist folder from the temporary container
docker cp temp-librechat:/app/client/dist ./client/

# Remove the temporary container
docker rm temp-librechat

# Check if extraction succeeded
if [ -d "client/dist" ]; then
    echo "✅ Client dist extracted successfully!"
    
    # Start the API container
    echo "Starting LibreChat..."
    docker compose up -d api
    
    echo "Waiting for container to start..."
    sleep 10
    
    # Check status
    docker compose ps
    
    echo ""
    echo "🎉 LibreChat should now be accessible at https://chat2.skoop.digital"
    echo ""
    echo "Testing the site..."
    curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://chat2.skoop.digital || echo "Local test failed, but site may still be accessible externally"
else
    echo "❌ Failed to extract client dist"
fi

