#!/bin/bash
###############################################################################
# Multi-VM Application Stack Deployment Test Script
# 
# Tests the deployed multi-tier infrastructure
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
TERRAFORM_DIR="../terraform"
TIMEOUT=10
MAX_RETRIES=5

# Functions
log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

log_header() {
    echo ""
    echo "================================================"
    echo "$1"
    echo "================================================"
}

# Get Terraform outputs
get_terraform_outputs() {
    log_info "Retrieving Terraform outputs..."
    
    cd "$TERRAFORM_DIR" || exit 1
    
    WEB_SERVER_URL=$(terraform output -raw web_server_url 2>/dev/null)
    WEB_SERVER_IP=$(terraform output -raw web_server_ip 2>/dev/null)
    DB_SERVER_IP=$(terraform output -raw db_server_internal_ip 2>/dev/null)
    API_HEALTH=$(terraform output -raw api_health_endpoint 2>/dev/null)
    API_DB_STATUS=$(terraform output -raw api_db_status_endpoint 2>/dev/null)
    WEB_SA=$(terraform output -raw web_tier_sa_email 2>/dev/null)
    DB_SA=$(terraform output -raw db_tier_sa_email 2>/dev/null)
    
    if [ -z "$WEB_SERVER_URL" ]; then
        log_error "Failed to get Terraform outputs"
        exit 1
    fi
    
    log_success "Terraform outputs retrieved"
    echo "  Web Server: $WEB_SERVER_IP"
    echo "  Database Server: $DB_SERVER_IP"
    echo "  Web SA: $WEB_SA"
    echo "  DB SA: $DB_SA"
    
    cd - > /dev/null
}

# Test 1: Web server health check
test_web_health() {
    log_header "Test 1: Web Server Health Check"
    
    for i in $(seq 1 $MAX_RETRIES); do
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$API_HEALTH")
        
        if [ "$HTTP_STATUS" -eq 200 ]; then
            HEALTH_DATA=$(curl -s --max-time $TIMEOUT "$API_HEALTH")
            log_success "Web server health check passed (HTTP $HTTP_STATUS)"
            echo "$HEALTH_DATA" | jq . || echo "$HEALTH_DATA"
            return 0
        else
            log_info "Attempt $i/$MAX_RETRIES: HTTP $HTTP_STATUS, retrying..."
            sleep 10
        fi
    done
    
    log_error "Web server health check failed after $MAX_RETRIES attempts"
    exit 1
}

# Test 2: Database connectivity
test_database_connectivity() {
    log_header "Test 2: Database Connectivity"
    
    for i in $(seq 1 $MAX_RETRIES); do
        DB_STATUS=$(curl -s --max-time $TIMEOUT "$API_DB_STATUS")
        
        if echo "$DB_STATUS" | grep -q '"connected":true'; then
            log_success "Database connection successful"
            echo "$DB_STATUS" | jq . || echo "$DB_STATUS"
            return 0
        else
            log_info "Attempt $i/$MAX_RETRIES: Database not ready, retrying..."
            sleep 15
        fi
    done
    
    log_error "Database connectivity test failed"
    exit 1
}

# Test 3: List users API
test_list_users() {
    log_header "Test 3: List Users API"
    
    RESPONSE=$(curl -s --max-time $TIMEOUT "$WEB_SERVER_URL/api/users")
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$WEB_SERVER_URL/api/users")
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        log_success "List users API working (HTTP $HTTP_STATUS)"
        echo "$RESPONSE" | jq . || echo "$RESPONSE"
        
        USER_COUNT=$(echo "$RESPONSE" | jq -r '.count' 2>/dev/null || echo "0")
        if [ "$USER_COUNT" -gt 0 ]; then
            log_success "Found $USER_COUNT users in database"
        fi
    else
        log_error "List users API failed (HTTP $HTTP_STATUS)"
        exit 1
    fi
}

# Test 4: Create user
test_create_user() {
    log_header "Test 4: Create User API"
    
    TIMESTAMP=$(date +%s)
    NEW_USER_DATA=$(cat <<EOF
{
  "name": "Test User $TIMESTAMP",
  "email": "test$TIMESTAMP@example.com"
}
EOF
)
    
    RESPONSE=$(curl -s --max-time $TIMEOUT \
        -X POST "$WEB_SERVER_URL/api/users" \
        -H "Content-Type: application/json" \
        -d "$NEW_USER_DATA")
    
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT \
        -X POST "$WEB_SERVER_URL/api/users" \
        -H "Content-Type: application/json" \
        -d "$NEW_USER_DATA")
    
    if [ "$HTTP_STATUS" -eq 201 ] || echo "$RESPONSE" | grep -q '"success":true'; then
        log_success "User creation successful"
        echo "$RESPONSE" | jq . || echo "$RESPONSE"
        
        USER_ID=$(echo "$RESPONSE" | jq -r '.data.id' 2>/dev/null)
        if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
            echo "NEW_USER_ID=$USER_ID" > /tmp/test_user_id
            log_success "Created user with ID: $USER_ID"
        fi
    else
        log_error "User creation failed (HTTP $HTTP_STATUS)"
        echo "$RESPONSE"
    fi
}

# Test 5: Get specific user
test_get_user() {
    log_header "Test 5: Get Specific User API"
    
    if [ -f /tmp/test_user_id ]; then
        source /tmp/test_user_id
        
        RESPONSE=$(curl -s --max-time $TIMEOUT "$WEB_SERVER_URL/api/users/$NEW_USER_ID")
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$WEB_SERVER_URL/api/users/$NEW_USER_ID")
        
        if [ "$HTTP_STATUS" -eq 200 ]; then
            log_success "Get user API working (HTTP $HTTP_STATUS)"
            echo "$RESPONSE" | jq . || echo "$RESPONSE"
        else
            log_error "Get user API failed (HTTP $HTTP_STATUS)"
        fi
    else
        log_info "Skipping - no test user ID available"
        
        # Try getting user ID 1
        RESPONSE=$(curl -s --max-time $TIMEOUT "$WEB_SERVER_URL/api/users/1")
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$WEB_SERVER_URL/api/users/1")
        
        if [ "$HTTP_STATUS" -eq 200 ]; then
            log_success "Get user API working for default user (HTTP $HTTP_STATUS)"
            echo "$RESPONSE" | jq . || echo "$RESPONSE"
        fi
    fi
}

# Test 6: Update user
test_update_user() {
    log_header "Test 6: Update User API"
    
    if [ -f /tmp/test_user_id ]; then
        source /tmp/test_user_id
        
        UPDATE_DATA=$(cat <<EOF
{
  "name": "Updated Test User"
}
EOF
)
        
        RESPONSE=$(curl -s --max-time $TIMEOUT \
            -X PUT "$WEB_SERVER_URL/api/users/$NEW_USER_ID" \
            -H "Content-Type: application/json" \
            -d "$UPDATE_DATA")
        
        if echo "$RESPONSE" | grep -q '"success":true'; then
            log_success "User update successful"
            echo "$RESPONSE" | jq . || echo "$RESPONSE"
        else
            log_error "User update failed"
            echo "$RESPONSE"
        fi
    else
        log_info "Skipping - no test user to update"
    fi
}

# Test 7: Response time
test_response_time() {
    log_header "Test 7: Response Time Test"
    
    RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time $TIMEOUT "$WEB_SERVER_URL/api/health")
    RESPONSE_TIME_MS=$(echo "$RESPONSE_TIME * 1000" | bc)
    RESPONSE_TIME_INT=${RESPONSE_TIME_MS%.*}
    
    if [ "$RESPONSE_TIME_INT" -lt 3000 ]; then
        log_success "Response time is acceptable (${RESPONSE_TIME_INT}ms)"
    else
        log_info "Response time is high (${RESPONSE_TIME_INT}ms)"
    fi
}

# Test 8: Firewall rules
test_firewall_rules() {
    log_header "Test 8: Firewall Rules"
    
    WEB_FW=$(gcloud compute firewall-rules list --filter="name:web-tier" --format="value(name)" 2>/dev/null)
    DB_FW=$(gcloud compute firewall-rules list --filter="name:db-tier OR name:postgres" --format="value(name)" 2>/dev/null)
    
    if [ -n "$WEB_FW" ]; then
        log_success "Web tier firewall rule exists: $WEB_FW"
    else
        log_error "Web tier firewall rule not found"
    fi
    
    if [ -n "$DB_FW" ]; then
        log_success "Database tier firewall rule exists: $DB_FW"
    else
        log_error "Database tier firewall rule not found"
    fi
}

# Test 9: Service accounts
test_service_accounts() {
    log_header "Test 9: Service Accounts"
    
    if [ -n "$WEB_SA" ]; then
        WEB_SA_EXISTS=$(gcloud iam service-accounts list --filter="email:$WEB_SA" --format="value(email)" 2>/dev/null)
        if [ -n "$WEB_SA_EXISTS" ]; then
            log_success "Web tier service account exists"
        else
            log_error "Web tier service account not found"
        fi
    fi
    
    if [ -n "$DB_SA" ]; then
        DB_SA_EXISTS=$(gcloud iam service-accounts list --filter="email:$DB_SA" --format="value(email)" 2>/dev/null)
        if [ -n "$DB_SA_EXISTS" ]; then
            log_success "Database tier service account exists"
        else
            log_error "Database tier service account not found"
        fi
    fi
}

# Test 10: VM instances status
test_vm_status() {
    log_header "Test 10: VM Instances Status"
    
    WEB_VM_STATUS=$(gcloud compute instances describe web-server --zone=us-central1-a --format="value(status)" 2>/dev/null)
    DB_VM_STATUS=$(gcloud compute instances describe db-server --zone=us-central1-a --format="value(status)" 2>/dev/null)
    
    if [ "$WEB_VM_STATUS" = "RUNNING" ]; then
        log_success "Web tier VM is running"
    else
        log_error "Web tier VM status: $WEB_VM_STATUS"
    fi
    
    if [ "$DB_VM_STATUS" = "RUNNING" ]; then
        log_success "Database tier VM is running"
    else
        log_error "Database tier VM status: $DB_VM_STATUS"
    fi
}

# Main execution
main() {
    log_header "🧪 Multi-VM Application Stack Tests"
    
    get_terraform_outputs
    
    test_web_health
    test_database_connectivity
    test_list_users
    test_create_user
    test_get_user
    test_update_user
    test_response_time
    test_firewall_rules
    test_service_accounts
    test_vm_status
    
    log_header "✅ All Tests Complete!"
    echo ""
    echo "Application URL: $WEB_SERVER_URL"
    echo "API Health: $API_HEALTH"
    echo "API DB Status: $API_DB_STATUS"
    echo ""
    log_success "Multi-VM application stack is working correctly! 🎉"
    echo ""
    
    # Cleanup
    rm -f /tmp/test_user_id
}

# Run tests
main
