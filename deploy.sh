#!/bin/bash
echo "Starting FinDuo Deployment..."

# Ensure we are in the right directory
cd "$(dirname "$0")"

# Pull latest changes
echo "Pulling latest changes from GitHub..."
git pull

# Stop existing containers
echo "Stopping existing containers..."
docker-compose down

# Build and start the containers in detached mode
echo "Building and starting containers..."
docker-compose up --build -d

echo "Deployment complete! Backend is running on port 8001."
