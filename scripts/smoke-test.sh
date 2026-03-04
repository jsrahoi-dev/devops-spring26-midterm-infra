#!/bin/bash
# smoke-test.sh - Basic health checks for deployed application

set -e

echo "Running smoke tests..."

# Test 1: Health endpoint
echo "Test 1: Health endpoint..."
HEALTH_RESPONSE=$(curl -s http://localhost:3000/api/health)
if echo "$HEALTH_RESPONSE" | grep -q '"status":"ok"'; then
  echo "✓ Health endpoint passed"
else
  echo "✗ Health endpoint failed"
  echo "Response: $HEALTH_RESPONSE"
  exit 1
fi

# Test 2: Frontend loads
echo "Test 2: Frontend HTML..."
FRONTEND_RESPONSE=$(curl -s http://localhost:3000/)
if echo "$FRONTEND_RESPONSE" | grep -q '<!DOCTYPE html>'; then
  echo "✓ Frontend loads"
else
  echo "✗ Frontend failed to load"
  exit 1
fi

# Test 3: API endpoints respond
echo "Test 3: Colors API..."
COLORS_RESPONSE=$(curl -s http://localhost:3000/api/colors/count)
if echo "$COLORS_RESPONSE" | grep -q '"total"'; then
  echo "✓ Colors API responds"
else
  echo "✗ Colors API failed"
  exit 1
fi

# Test 4: Database connection
echo "Test 4: Database connection..."
if echo "$HEALTH_RESPONSE" | grep -q '"db":"connected"'; then
  echo "✓ Database connected"
else
  echo "✗ Database connection failed"
  exit 1
fi

echo ""
echo "All smoke tests passed! ✓"
