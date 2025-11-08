#!/bin/bash

echo "========================================"
echo "  Health Check - Quotes Application"
echo "========================================"

cd /opt/app

MAX_ATTEMPTS=30
ATTEMPT=0

# Function to check container health
check_containers() {
    RUNNING=$(docker-compose ps -q | wc -l)
    EXPECTED=3
    
    if [ $RUNNING -ne $EXPECTED ]; then
        echo "❌ Expected $EXPECTED containers, found $RUNNING"
        return 1
    fi
    
    # Check if all containers are in healthy state
    UNHEALTHY=$(docker-compose ps | grep -c "Exit\|Restarting" || true)
    if [ $UNHEALTHY -gt 0 ]; then
        echo "❌ Found unhealthy containers"
        return 1
    fi
    
    return 0
}

# Function to check MySQL database
check_database() {
    docker-compose exec -T db mysql -uroot -proot -e "SELECT 1;" quotesdb > /dev/null 2>&1
    return $?
}

# Function to check API endpoint
check_api() {
    # Check if API is responding on port 5001
    curl -f -s http://localhost:5001/ > /dev/null 2>&1 || \
    curl -f -s http://localhost:5001/health > /dev/null 2>&1 || \
    curl -f -s http://localhost:5001/api/quotes > /dev/null 2>&1
    return $?
}

# Function to check Frontend
check_frontend() {
    # Check if frontend is responding on port 5002
    curl -f -s http://localhost:5002/ > /dev/null 2>&1
    return $?
}

echo "Starting health checks..."
echo ""

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT+1))
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS"
    
    # Check 1: Container Status
    echo -n "  ├─ Checking containers... "
    if check_containers; then
        echo "✅"
    else
        echo "❌ (retrying)"
        sleep 10
        continue
    fi
    
    # Check 2: Database
    echo -n "  ├─ Checking database... "
    if check_database; then
        echo "✅"
    else
        echo "❌ (retrying)"
        sleep 10
        continue
    fi
    
    # Check 3: API
    echo -n "  ├─ Checking API (port 5001)... "
    if check_api; then
        echo "✅"
    else
        echo "❌ (retrying)"
        sleep 10
        continue
    fi
    
    # Check 4: Frontend
    echo -n "  └─ Checking Frontend (port 5002)... "
    if check_frontend; then
        echo "✅"
    else
        echo "❌ (retrying)"
        sleep 10
        continue
    fi
    
    # All checks passed
    echo ""
    echo "========================================"
    echo "✅ ALL HEALTH CHECKS PASSED!"
    echo "========================================"
    echo ""
    echo "Service Details:"
    echo "  - Database: MySQL on port 3306"
    echo "  - API: Running on port 5001"
    echo "  - Frontend: Running on port 5002"
    echo ""
    echo "Container Status:"
    docker-compose ps
    echo ""
    echo "Docker Volumes:"
    docker volume ls | grep db-data || echo "  db-data volume created"
    echo ""
    echo "========================================"
    exit 0
done

# If we got here, health checks failed
echo ""
echo "========================================"
echo "❌ HEALTH CHECKS FAILED"
echo "========================================"
echo ""
echo "Container Status:"
docker-compose ps
echo ""
echo "Recent Logs:"
docker-compose logs --tail=50
echo ""
echo "========================================"
exit 1
