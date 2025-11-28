# Operations Guide

This guide covers common operational tasks, troubleshooting, and testing for the multi-VM application stack.

## 🚀 Deployment Testing

### Quick Verification

After deploying, wait 5-7 minutes for both VMs to complete startup scripts, then test:

```bash
# Get web server IP
cd terraform
WEB_IP=$(terraform output -raw web_server_external_ip)

# Test health endpoint
curl http://$WEB_IP/api/health

# Test database connectivity
curl http://$WEB_IP/api/db-status

# Test user API
curl http://$WEB_IP/api/users
```

### Comprehensive Testing

Run the automated verification script:

```bash
cd tests
./verify_deployment.sh $WEB_IP
```

This script performs 600 seconds (10 minutes) of checks with 30-second intervals, testing:
- Basic connectivity
- Web server health
- Database connectivity
- API endpoints
- Response times

## 🐛 Common Issues and Solutions

### 1. Health Check Endpoint Not Responding

**Symptoms:**
- `curl http://<WEB_IP>/api/health` returns connection refused or timeout
- Application not accessible

**Solutions:**

#### Wait for Startup (Most Common)
Startup scripts take 3-5 minutes. Wait at least 5 minutes after `terraform apply` completes.

#### Check Application Status
```bash
# SSH into web server
gcloud compute ssh web-server --zone=us-central1-a

# Check webapp service
sudo systemctl status webapp
sudo journalctl -u webapp -n 50 --no-pager

# Check Nginx
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log

# Restart if needed
sudo systemctl restart webapp
```

### 2. Database Connectivity Issues

**Symptoms:**
- `/api/db-status` returns `"connected": false`
- Web logs show PostgreSQL connection errors
- 503 Service Unavailable errors

**Solutions:**

#### Check PostgreSQL Status
```bash
# SSH into database server
gcloud compute ssh db-server --zone=us-central1-a

# Check PostgreSQL service
sudo systemctl status postgresql
sudo tail -f /var/log/postgresql/postgresql-15-main.log

# Restart if needed
sudo systemctl restart postgresql
```

#### Verify Network Connectivity
```bash
# From web server, test database connectivity
ping <DB_INTERNAL_IP>
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/<DB_INTERNAL_IP>/5432' && echo "DB reachable" || echo "DB not reachable"

# Check firewall rules
gcloud compute firewall-rules list --filter="name:postgres"
```

#### Verify Database Configuration
```bash
# SSH into database server
sudo -u postgres psql

# List databases
\l

# Connect to appdb
\c appdb

# List tables
\dt

# Check users
SELECT * FROM users;
```

### 3. Firewall Rules Not Working

**Symptoms:**
- Cannot access web server from internet
- Web server cannot reach database

**Solutions:**

```bash
# List all firewall rules
gcloud compute firewall-rules list

# Check VM network tags
gcloud compute instances describe web-server --zone=us-central1-a --format="get(tags.items)"
gcloud compute instances describe db-server --zone=us-central1-a --format="get(tags.items)"

# Verify required tags:
# Web server: web-tier, http-server
# Database server: db-tier

# Add missing tags if needed
gcloud compute instances add-tags web-server --tags=web-tier,http-server --zone=us-central1-a
gcloud compute instances add-tags db-server --tags=db-tier --zone=us-central1-a
```

### 4. Startup Scripts Failed

**Symptoms:**
- Services not running after 10+ minutes
- No completion marker files

**Check Startup Progress:**

```bash
# View serial console output (boot logs)
gcloud compute instances get-serial-port-output web-server --zone=us-central1-a | tail -100
gcloud compute instances get-serial-port-output db-server --zone=us-central1-a | tail -100

# On the VM, check startup logs
sudo tail -100 /var/log/web-startup.log  # or db-startup.log

# Check for completion marker
ls -la /var/log/web-startup-complete.marker
ls -la /var/log/db-startup-complete.marker
```

## 📊 Monitoring and Logs

### Application Logs

**Web Server:**
```bash
# Application logs
sudo journalctl -u webapp -f

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Startup script log
sudo tail -f /var/log/web-startup.log
```

**Database Server:**
```bash
# PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-15-main.log

# Startup script log
sudo tail -f /var/log/db-startup.log
```

### Cloud Logging Queries

```
# Web tier logs
resource.type="gce_instance"
resource.labels.instance_id="<web-instance-id>"

# Database tier logs
resource.type="gce_instance"
resource.labels.instance_id="<db-instance-id>"
```

## 🔧 Operational Tasks

### Restart Services

**Web Tier:**
```bash
gcloud compute ssh web-server --zone=us-central1-a
sudo systemctl restart webapp
sudo systemctl restart nginx
```

**Database Tier:**
```bash
gcloud compute ssh db-server --zone=us-central1-a
sudo systemctl restart postgresql
```

### Access Database from Web Tier

```bash
# SSH to web tier
gcloud compute ssh web-server --zone=us-central1-a

# Get database credentials from metadata
DB_HOST=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/db-host -H "Metadata-Flavor: Google")
DB_NAME=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/db-name -H "Metadata-Flavor: Google")
DB_USER=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/db-user -H "Metadata-Flavor: Google")

# Connect to database (you'll be prompted for password)
PGPASSWORD='<your-password>' psql -h $DB_HOST -U $DB_USER -d $DB_NAME
```

### Check VM Status

```bash
# List all VMs
gcloud compute instances list --filter="zone:us-central1-a"

# Get detailed info
gcloud compute instances describe web-server --zone=us-central1-a
gcloud compute instances describe db-server --zone=us-central1-a
```

### Performance Monitoring

```bash
# Check CPU and memory
top

# Check disk usage
df -h

# Check network connections
sudo ss -tuln

# For PostgreSQL specifically
sudo ss -tuln | grep 5432
```

## 🧪 API Testing

### Health Check
```bash
curl http://$WEB_IP/api/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-28T12:00:00Z",
  "tier": "web",
  "database": "connected"
}
```

### Database Status
```bash
curl http://$WEB_IP/api/db-status
```

Expected response:
```json
{
  "connected": true,
  "database": "appdb",
  "tables": ["users"],
  "recordCount": 5
}
```

### CRUD Operations

```bash
# List users
curl http://$WEB_IP/api/users

# Get specific user
curl http://$WEB_IP/api/users/1

# Create user
curl -X POST http://$WEB_IP/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}'

# Update user
curl -X PUT http://$WEB_IP/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Name"}'

# Delete user
curl -X DELETE http://$WEB_IP/api/users/1
```

## 🔄 Clean Rebuild

If all troubleshooting fails, perform a clean rebuild:

```bash
cd terraform

# Destroy infrastructure
terraform destroy -auto-approve

# Wait for cleanup
sleep 60

# Re-initialize and apply
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Wait for startup scripts (5-7 minutes)
sleep 420

# Test
WEB_IP=$(terraform output -raw web_server_external_ip)
curl http://$WEB_IP/api/health
```

## 💡 Tips for Success

1. **Always wait 5-7 minutes** after `terraform apply` before testing
2. **Check serial console logs** if SSH isn't working yet
3. **503 errors are normal** during startup - database may not be ready
4. **Use verify_deployment.sh** for automated testing with retries
5. **Check firewall rules** if connectivity issues persist
6. **Review logs** systematically: webapp → nginx → postgresql

## 📞 Getting Help

When reporting issues, provide:
1. Full error messages
2. Relevant logs (webapp, nginx, postgresql)
3. Terraform output
4. VM status from `gcloud compute instances list`
5. Firewall rules from `gcloud compute firewall-rules list`

### Key Debug Commands

```bash
# Get all Terraform outputs
terraform output

# Check VM status
gcloud compute instances list

# Check firewall rules
gcloud compute firewall-rules list

# View serial console (boot logs)
gcloud compute instances get-serial-port-output web-server --zone=us-central1-a
gcloud compute instances get-serial-port-output db-server --zone=us-central1-a
```
