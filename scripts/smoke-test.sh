#!/bin/bash
# smoke-test.sh - Basic health checks for deployed application
# Usage: ./smoke-test.sh <host>

set -e

HOST=${1:-"localhost"}
echo "Running smoke tests against: $HOST"
echo ""

# Test 1: Health endpoint
echo "Test 1: Health endpoint..."
HEALTH_RESPONSE=$(curl -sf http://$HOST/api/health || echo "failed")
if echo "$HEALTH_RESPONSE" | grep -q '"status":"ok"'; then
  echo "✓ Health endpoint passed"
else
  echo "✗ Health endpoint failed"
  echo "Response: $HEALTH_RESPONSE"
  exit 1
fi

# Test 2: Frontend loads
echo "Test 2: Frontend HTML..."
FRONTEND_RESPONSE=$(curl -sf http://$HOST/ || echo "failed")
if echo "$FRONTEND_RESPONSE" | grep -q '<!doctype html>'; then
  echo "✓ Frontend loads"
else
  echo "✗ Frontend failed to load"
  exit 1
fi

# Test 3: API endpoints respond
echo "Test 3: Colors API..."
COLORS_RESPONSE=$(curl -sf http://$HOST/api/colors/next || echo "failed")
if echo "$COLORS_RESPONSE" | grep -q '"color"'; then
  echo "✓ Colors API responds"
else
  echo "✗ Colors API failed"
  echo "Response: $COLORS_RESPONSE"
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

# Test 5: Static assets
echo "Test 5: Static assets (JS/CSS)..."
if curl -sf http://$HOST/ | grep -q '/assets/index-'; then
  echo "✓ Static assets referenced"
else
  echo "✗ Static assets not found"
  exit 1
fi

echo ""
echo "🎉 All smoke tests passed!"
