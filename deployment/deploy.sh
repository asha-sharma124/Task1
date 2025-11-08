#!/bin/bash
set -e

DOCKER_USERNAME=$1
IMAGE_TAG=$2
DOCKER_PASSWORD=$3

echo "========================================"
echo "  Deploying Quotes Application"
echo "========================================"
echo "Docker Username: $DOCKER_USERNAME"
echo "Image Tag: $IMAGE_TAG"
echo "Timestamp: $(date)"
echo "========================================"

# Navigate to app directory
cd /opt/app

# Login to Docker Hub
echo "Logging into Docker Hub..."
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

# Stop and remove existing containers (if any)
echo "Stopping existing containers..."
docker-compose down -v 2>/dev/null || true

# Clean up old containers and images
echo "Cleaning up old Docker resources..."
docker container prune -f || true
docker image prune -af --filter "until=24h" || true

# Pull latest images
echo "Pulling latest images..."
docker-compose pull

# Start services
echo "Starting services with docker-compose..."
docker-compose up -d

# Wait for containers to be ready
echo "Waiting for containers to start (30 seconds)..."
sleep 30

# Check container status
echo "========================================"
echo "Container Status:"
docker-compose ps
echo "========================================"

# Verify all containers are running
RUNNING=$(docker-compose ps -q | wc -l)
EXPECTED=3  # db, api, app

if [ $RUNNING -eq $EXPECTED ]; then
    echo "✅ All $EXPECTED containers are running"
    
    # Show container logs
    echo "========================================"
    echo "Recent logs:"
    docker-compose logs --tail=20
    echo "========================================"
    
    echo "✅ Deployment completed successfully!"
    exit 0
else
    echo "❌ Expected $EXPECTED containers, but only $RUNNING are running"
    echo "========================================"
    docker-compose logs
    echo "========================================"
    exit 1
fi
