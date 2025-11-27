# Troubleshooting Guide

This guide helps you diagnose and fix common issues with the multi-VM application deployment.

## Common Issues and Solutions

### 1. Health Check Endpoint Not Responding

**Symptoms:**
- `curl http://<WEB_IP>/api/health` returns connection refused or timeout
- GitHub Actions tests fail on health check

**Possible Causes & Solutions:**

#### A. Services Still Starting
The startup scripts take 3-5 minutes to complete:
- PostgreSQL installation: ~60-90 seconds
- Node.js and npm packages: ~60-90 seconds  
- Application startup: ~30 seconds

**Solution:** Wait at least 5 minutes after `terraform apply` completes before testing.

#### B. Node.js Application Failed to Start
**Debug Steps:**
```bash
# SSH into web server
gcloud compute ssh web-server --zone=us-central1-a

# Check webapp service status
sudo systemctl status webapp

# Check application logs
sudo journalctl -u webapp -n 100 --no-pager

# Check for errors
sudo journalctl -u webapp | grep -i error
```

**Common Issues:**
- Missing dependencies: `npm install` failed
- Port already in use
- Environment variables not set

**Fix:**
```bash
# Restart the service
sudo systemctl restart webapp

# If needed, reinstall dependencies
cd /opt/webapp
sudo npm install --production
sudo systemctl restart webapp
```

#### C. Nginx Not Running or Misconfigured
**Debug Steps:**
```bash
# Check Nginx status
sudo systemctl status nginx

# Test Nginx configuration
sudo nginx -t

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

**Fix:**
```bash
sudo systemctl restart nginx
```

### 2. Database Connectivity Issues

**Symptoms:**
- `/api/db-status` returns `"connected": false`
- Web application logs show PostgreSQL connection errors

**Possible Causes & Solutions:**

#### A. PostgreSQL Not Running
**Debug Steps:**
```bash
# SSH into database server
gcloud compute ssh db-server --zone=us-central1-a

# Check PostgreSQL status
sudo systemctl status postgresql

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-15-main.log
```

**Fix:**
```bash
sudo systemctl restart postgresql
```

#### B. Network Connectivity Issues
**Debug Steps:**
```bash
# From web server, test connectivity to database
ping <DB_INTERNAL_IP>
telnet <DB_INTERNAL_IP> 5432

# Check firewall rules
gcloud compute firewall-rules list
```

**Verify Firewall Rules:**
- `allow-postgres-from-web`: Allows port 5432 from web-tier tag to db-tier tag
- `allow-internal-tier-communication`: Allows all internal traffic

#### C. Database Not Created or Credentials Wrong
**Debug Steps:**
```bash
# SSH into database server
gcloud compute ssh db-server --zone=us-central1-a

# Connect to PostgreSQL
sudo -u postgres psql

# List databases
\l

# Connect to your database
\c appdb

# List tables
\dt

# Check users table
SELECT * FROM users;
```

**Fix if database missing:**
```bash
# Re-run the database setup portion of startup script
sudo -u postgres psql -c "CREATE DATABASE appdb;"
sudo -u postgres psql -c "CREATE USER appuser WITH PASSWORD 'your-password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;"
```

### 3. Firewall Rules Not Working

**Symptoms:**
- Cannot access web server from internet
- Web server cannot reach database server

**Debug Steps:**
```bash
# List all firewall rules
gcloud compute firewall-rules list

# Check specific rule
gcloud compute firewall-rules describe allow-http-web-tier

# Check VM network tags
gcloud compute instances describe web-server --zone=us-central1-a --format="get(tags.items)"
gcloud compute instances describe db-server --zone=us-central1-a --format="get(tags.items)"
```

**Required Tags:**
- Web server: `web-tier`, `http-server`
- Database server: `db-tier`

**Fix:**
```bash
# Add missing tags
gcloud compute instances add-tags web-server --tags=web-tier,http-server --zone=us-central1-a
gcloud compute instances add-tags db-server --tags=db-tier --zone=us-central1-a
```

### 4. API Enablement Issues

**Symptoms:**
- Terraform apply fails with "API not enabled" errors
- Error mentions compute.googleapis.com or iam.googleapis.com

**Solution:**
The `apis.tf` file should automatically enable required APIs, but they take 30-60 seconds to activate.

**Manual Fix:**
```bash
gcloud services enable compute.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable serviceusage.googleapis.com
```

### 5. Terraform State Issues

**Symptoms:**
- "Error acquiring state lock"
- "State file is corrupt"
- "Backend configuration changed"

**Solutions:**

#### State Lock
```bash
# Force unlock (use the Lock ID from error message)
cd terraform
terraform force-unlock <LOCK_ID>
```

#### Re-initialize Backend
```bash
cd terraform
rm -rf .terraform
terraform init -reconfigure
```

## Testing Checklist

Use this checklist to verify your deployment:

```bash
# 1. Get the web server IP
cd terraform
WEB_IP=$(terraform output -raw web_server_external_ip)

# 2. Test basic connectivity
ping -c 3 $WEB_IP
curl -I http://$WEB_IP

# 3. Test health endpoint
curl http://$WEB_IP/api/health

# 4. Test database connectivity
curl http://$WEB_IP/api/db-status

# 5. Test user API
curl http://$WEB_IP/api/users

# 6. Run comprehensive tests
../tests/verify_deployment.sh $WEB_IP
```

## Monitoring and Logs

### Web Server Logs
```bash
# Application logs
sudo journalctl -u webapp -f

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Startup script logs
sudo tail -f /var/log/web-startup.log
```

### Database Server Logs
```bash
# PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-15-main.log

# Startup script logs
sudo tail -f /var/log/db-startup.log
```

## Performance Issues

### High CPU Usage
```bash
# Check top processes
top

# Check Node.js process
ps aux | grep node

# Restart application if needed
sudo systemctl restart webapp
```

### Memory Issues
```bash
# Check memory usage
free -h

# Check swap usage
swapon --show

# View memory by process
ps aux --sort=-%mem | head
```

## Clean Rebuild

If all else fails, destroy and recreate:

```bash
# Destroy infrastructure
cd terraform
terraform destroy -auto-approve

# Wait a minute for cleanup
sleep 60

# Re-apply
terraform init
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

# Wait for services to start (5 minutes)
sleep 300

# Test
WEB_IP=$(terraform output -raw web_server_external_ip)
curl http://$WEB_IP/api/health
```

## Getting Help

When asking for help, provide:

1. **Error messages** (full text)
2. **Logs** from affected services
3. **Terraform output** from failed commands
4. **GCP Console screenshots** if relevant
5. **Steps to reproduce** the issue

### Useful Debug Commands
```bash
# Get all outputs
terraform output

# Check VM status
gcloud compute instances list

# Check firewall rules
gcloud compute firewall-rules list

# Check service accounts
gcloud iam service-accounts list

# View VM serial port output (boot logs)
gcloud compute instances get-serial-port-output web-server --zone=us-central1-a
gcloud compute instances get-serial-port-output db-server --zone=us-central1-a
```
