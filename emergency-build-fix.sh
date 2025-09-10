#!/bin/bash

echo "🚨 Emergency Fix: Building client locally and copying to container"

# Stop the API container
echo "Stopping API container..."
docker compose stop api

# Build the client locally
echo "Building client locally..."
cd client

# Install dependencies
npm install

# Fix the build script to use npx
sed -i 's/"build": "cross-env NODE_ENV=production vite build/"build": "cross-env NODE_ENV=production npx vite build/' package.json

# Build
npm run build

# Check if build succeeded
if [ -d "dist" ]; then
    echo "✅ Build succeeded! Copying dist folder to container..."
    
    # Start the container without the application running
    cd ..
    docker compose run -d --rm --entrypoint sh api -c "sleep 3600"
    
    # Get the container ID
    CONTAINER_ID=$(docker ps | grep "sh -c sleep" | awk '{print $1}')
    
    # Copy the dist folder
    docker cp client/dist $CONTAINER_ID:/app/client/
    
    # Stop the temporary container
    docker stop $CONTAINER_ID
    
    # Start the API normally
    docker compose up -d api
    
    echo "✅ Fix applied! Checking status..."
    sleep 5
    docker compose ps
    
    echo ""
    echo "🎉 LibreChat should now be accessible!"
else
    echo "❌ Build failed. Please check the error messages above."
fi

