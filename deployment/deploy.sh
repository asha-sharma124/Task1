# #!/bin/bash
# set -e

# DOCKER_USERNAME=$1
# IMAGE_TAG=$2
# DOCKER_PASSWORD=$3
# DEPLOYMENT_ENV=$4

# APP_DIR="/home/ubuntu/quotes-app"

# cd $APP_DIR

# echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin


# docker-compose down 

# docker container prune -f || true

# docker image prune -af --filter "until=24h" || true
# # #docker rm -f quotes-app-app-1

# # cat > $APP_DIR/.env << EOF
# # DOCKER_USERNAME=${DOCKER_USERNAME}
# # IMAGE_TAG=${IMAGE_TAG}
# # DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
# # TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# # EOF

# docker-compose pull -q

# echo "Starting containers..."
# docker-compose up -d

# sleep 20


# # cd /etc/nginx/sites-enabled
# # rm -rf default
# # cp /home/ubuntu/quotes-app/quotes.conf /etc/nginx/conf.d/
# # sudo systemctl restart nginx


#!/bin/bash
# deploy.sh
# Usage: bash deploy.sh <docker_username> <image_tag> <docker_password> <environment>

set -e

DOCKER_USERNAME=$1
IMAGE_TAG=$2
DOCKER_PASSWORD=$3
ENVIRONMENT=$4

# Logging
LOG_FILE="/var/log/deployment.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=========================================="
echo "Starting deployment at $(date)"
echo "Image Tag: $IMAGE_TAG"
echo "Environment: $ENVIRONMENT"
echo "=========================================="

# Docker login
echo "Logging into Docker Hub..."
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

# Stop existing containers
echo "Stopping existing containers..."
if [ -f docker-compose.yml ]; then
    docker-compose down || true
fi

# Clean up old containers and images
echo "Cleaning up old resources..."
docker container prune -f || true
docker image prune -af --filter "until=24h" || true

# Pull latest images
echo "Pulling Docker images with tag: $IMAGE_TAG..."
docker-compose pull || exit 1

# Start new containers
echo "Starting containers with docker-compose..."
docker-compose up -d || exit 1

# Wait for containers to be ready
echo "Waiting for containers to start..."
sleep 30

# Health check
echo "Performing health check..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    
    # Check if containers are running
    RUNNING_CONTAINERS=$(docker-compose ps --services --filter "status=running" | wc -l)
    TOTAL_CONTAINERS=$(docker-compose ps --services | wc -l)
    
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS - Running: $RUNNING_CONTAINERS/$TOTAL_CONTAINERS"
    
    if [ $RUNNING_CONTAINERS -eq $TOTAL_CONTAINERS ]; then
        # Check if app is responding on port 80
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80 || echo "000")
        
        if [ "$HTTP_STATUS" = "200" ]; then
            echo "✅ Health check passed! Application is responding on port 80"
            break
        else
            echo "⏳ HTTP status: $HTTP_STATUS, waiting..."
        fi
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "❌ Health check failed after $MAX_ATTEMPTS attempts"
        echo "Container status:"
        docker-compose ps
        echo "Container logs:"
        docker-compose logs --tail=50
        exit 1
    fi
    
    sleep 10
done

# Final verification
echo "Final verification..."
docker-compose ps

echo "=========================================="
echo "✅ Deployment completed successfully at $(date)"
echo "Image Tag: $IMAGE_TAG"
echo "=========================================="

# Logout from Docker
docker logout

exit 0
