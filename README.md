# Project 2: Multi-VM Application Stack ⭐

A beginner-friendly GCP project that deploys a two-tier application architecture with a web server frontend and a PostgreSQL database backend, demonstrating inter-VM networking and service communication.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│               Internet Traffic                      │
└───────────────────┬─────────────────────────────────┘
                    │
                    ▼
┌───────────────────────────────────────────────────┐
│        Firewall Rule (Allow HTTP/80)              │
└───────────────────┬───────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│                  Web Tier VM                        │
│  ┌───────────────────────────────────────────┐     │
│  │   Node.js Application Server              │     │
│  │   - Express.js API                        │     │
│  │   - Nginx Reverse Proxy                   │     │
│  │   - Connects to Database Tier             │     │
│  └───────────────────────────────────────────┘     │
│                                                     │
│  - External IP Address                              │
│  - Custom Service Account                           │
└─────────────────────┬───────────────────────────────┘
                      │ Internal Network
                      │ (Port 5432)
                      ▼
┌─────────────────────────────────────────────────────┐
│                Database Tier VM                      │
│  ┌───────────────────────────────────────────┐     │
│  │   PostgreSQL Database Server              │     │
│  │   - Port 5432                             │     │
│  │   - Private Network Only                  │     │
│  │   - Cloud NAT for Internet Access         │     │
│  └───────────────────────────────────────────┘     │
│                                                     │
│  - Internal IP Only (No External IP)                │
│  - Cloud NAT for Package Installation               │
│  - Custom Service Account                           │
└─────────────────────────────────────────────────────┘
```

## 🎯 Learning Objectives

- Deploy multi-tier application architecture
- Configure internal networking between VMs
- Implement security best practices (private DB tier)
- Configure Cloud NAT for private VM internet access
- Use separate service accounts per tier
- Manage firewall rules for different tiers
- Work with VM metadata for configuration
- Implement startup scripts for application deployment
- Connect web and database tiers securely
- Monitor multi-VM infrastructure

## 📋 Prerequisites

- GCP Project with billing enabled
- Terraform >= 1.6 installed
- `gcloud` CLI configured
- GitHub repository
- GitHub Secrets configured (`GCP_SA_KEY`)
- Basic understanding of Node.js and PostgreSQL

## 🔧 Tech Stack

- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **Web Tier**: Node.js + Express.js + Nginx
- **Database Tier**: PostgreSQL 15
- **Compute**: 2x GCE VMs (e2-micro)
- **Networking**: VPC internal networking, Cloud NAT, Cloud Router, firewall rules
- **IAM**: 2 Custom Service Accounts (one per tier)
- **State Management**: GCS backend (remote state)

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone <your-repo-url>
cd project-02-multi-vm-application-stack
```

### 2. Configure Variables
Edit `terraform/terraform.tfvars`:
```hcl
project_id        = "your-gcp-project-id"
region            = "us-central1"
zone              = "us-central1-a"
db_password       = "your-secure-password"  # Change this!
```

### 3. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Test the Application
```bash
# Get web server IP
terraform output web_server_url

# Test API endpoints
curl http://<WEB_IP>/api/health
curl http://<WEB_IP>/api/db-status
curl http://<WEB_IP>/api/users
```

## 📁 Project Structure

```
project-02-multi-vm-application-stack/
├── .github/
│   └── workflows/
│       ├── deploy.yml         # Automated deployment
│       └── destroy.yml        # Safe destruction
├── terraform/
│   ├── backend.tf             # GCS remote state configuration
│   ├── apis.tf                # Enable required GCP APIs
│   ├── main.tf                # Provider configuration
│   ├── variables.tf           # Input variables
│   ├── terraform.tfvars       # Variable values (gitignored)
│   ├── resources.tf           # VM instances and service accounts
│   ├── network.tf             # Firewall rules
│   ├── nat.tf                 # Cloud NAT and Cloud Router
│   └── outputs.tf             # Output values
├── scripts/
│   ├── web-tier-startup.sh    # Web server initialization
│   ├── db-tier-startup.sh     # Database initialization
│   └── app/                   # Node.js application code
│       ├── server.js          # Express.js server
│       └── package.json       # NPM dependencies
├── docs/
│   └── OPERATIONS.md          # Operations and troubleshooting guide
├── tests/
│   └── verify_deployment.sh   # Automated deployment verification
├── README.md
└── .gitignore
```

## 🔐 Security Architecture

### Service Accounts

**Web Tier Service Account:**
- `roles/logging.logWriter` - Write logs
- `roles/monitoring.metricWriter` - Write metrics

**Database Tier Service Account:**
- `roles/logging.logWriter` - Write logs
- `roles/monitoring.metricWriter` - Write metrics
- No external network access

### Network Security

**Firewall Rules:**
1. **Web Tier**: Allow HTTP (80) from Internet (0.0.0.0/0)
2. **Database Tier**: Allow PostgreSQL (5432) only from Web Tier
3. **Internal Communication**: Allow all internal traffic between tiers
4. **SSH**: Disabled by default (use IAP tunnel if needed)

**Cloud NAT Configuration:**
- Database VM has no external IP for security
- Cloud NAT + Cloud Router provides controlled internet access
- Enables package installation (PostgreSQL) from private VM
- NAT gateway with automatic IP allocation
- Endpoint-independent mapping for better connectivity

**Key Security Features:**
- Database has no external IP
- Database only accepts connections from web tier
- Separate service accounts per tier
- Principle of least privilege applied
- No default Compute Engine service accounts
- Cloud NAT enables outbound-only internet access

## 🧪 Testing

### Manual Testing
```bash
cd terraform

# Get outputs
WEB_URL=$(terraform output -raw web_server_url)
echo "Web Server URL: $WEB_URL"

# Test health endpoint
curl $WEB_URL/api/health

# Test database connectivity
curl $WEB_URL/api/db-status

# Test CRUD operations
# Create user
curl -X POST $WEB_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'

# List users
curl $WEB_URL/api/users

# Get specific user
curl $WEB_URL/api/users/1
```

### Automated Testing
```bash
cd tests
chmod +x verify_deployment.sh

# Get web server IP from Terraform
WEB_IP=$(terraform -chdir=../terraform output -raw web_server_external_ip)

# Run verification (waits up to 10 minutes for deployment)
./verify_deployment.sh $WEB_IP
```

### Database Access (via Web Tier)
```bash
# SSH to web tier
gcloud compute ssh web-server --zone=us-central1-a

# Connect to database from web tier
psql -h <DB_INTERNAL_IP> -U appuser -d appdb
```

## 📊 Application Features

The deployed Node.js application provides:

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Application health check |
| GET | `/api/db-status` | Database connectivity status |
| GET | `/api/users` | List all users |
| GET | `/api/users/:id` | Get specific user |
| POST | `/api/users` | Create new user |
| PUT | `/api/users/:id` | Update user |
| DELETE | `/api/users/:id` | Delete user |

### Sample API Responses

**Health Check:**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-25T12:00:00Z",
  "tier": "web",
  "database": "connected"
}
```

**DB Status:**
```json
{
  "connected": true,
  "database": "appdb",
  "tables": ["users"],
  "recordCount": 5
}
```

## 💰 Cost Estimate

**Monthly Cost (US Central1):**
- Web Tier VM (e2-micro): ~$7.50/month
- Database Tier VM (e2-micro): ~$7.50/month
- External IP (Web Tier): ~$4.00/month
- Network Egress: ~$1.00/month
- **Total**: ~$20.00/month

**Cost Optimization:**
- Use preemptible VMs for dev/test (~70% discount)
- Stop VMs when not needed
- Use e2-small for better performance (+$5/month per VM)

## 🔄 Architecture Benefits

**Why This Design:**
1. **Security**: Database isolated from internet
2. **Scalability**: Can add multiple web tier VMs
3. **Maintainability**: Clear separation of concerns
4. **Monitoring**: Independent health checks per tier
5. **Cost-Effective**: Minimal resources for learning

**Production Enhancements:**
- Add load balancer for web tier
- Implement Cloud SQL instead of self-managed PostgreSQL
- Add Cloud Armor for DDoS protection
- Use managed instance groups for auto-scaling
- Add Cloud CDN for static assets
- Implement proper backup strategy

## 🐛 Troubleshooting

For comprehensive troubleshooting, operations guides, and testing procedures, see **[docs/OPERATIONS.md](docs/OPERATIONS.md)**.

### Quick Tips

**Wait for Startup**: Allow 5-7 minutes after deployment for both VMs to complete initialization.

**Check Application Status:**
```bash
# SSH into web server
gcloud compute ssh web-server --zone=us-central1-a
sudo systemctl status webapp
sudo journalctl -u webapp -n 50
```

**Check Database Status:**
```bash
# SSH into database server
gcloud compute ssh db-server --zone=us-central1-a
sudo systemctl status postgresql
```

**View Serial Console Logs:**
```bash
# Check startup script progress
gcloud compute instances get-serial-port-output web-server --zone=us-central1-a | tail -100
gcloud compute instances get-serial-port-output db-server --zone=us-central1-a | tail -100
```

For detailed troubleshooting steps, common issues, and solutions, see the **[Operations Guide](docs/OPERATIONS.md)**.

## 📊 Monitoring

### Cloud Logging Queries

**Web Tier Logs:**
```
resource.type="gce_instance"
resource.labels.instance_id="<web-instance-id>"
```

**Database Logs:**
```
resource.type="gce_instance"
resource.labels.instance_id="<db-instance-id>"
```

### Metrics to Monitor
- CPU utilization (both VMs)
- Memory usage
- Network traffic between tiers
- API response times
- Database connection count
- Database query performance

## 🧹 Cleanup

### Using Terraform
```bash
cd terraform
terraform destroy
```

### Using GitHub Actions
1. Go to Actions tab
2. Run "Destroy Infrastructure" workflow
3. Enter "destroy" to confirm

**What Gets Deleted:**
- Both VM instances (web + database)
- All firewall rules
- Both service accounts
- External IP address
- All data in database

## 🎓 Learning Outcomes

After completing this project, you'll understand:
- ✅ Multi-tier application architecture
- ✅ Internal VM networking in GCP
- ✅ Service account best practices
- ✅ Firewall rule configuration
- ✅ Startup script automation
- ✅ Database security patterns
- ✅ API development and deployment
- ✅ Infrastructure testing strategies

## 📚 Next Steps

**Project Progression:**
1. ✅ **Project 1**: Simple Web Server (completed)
2. ✅ **Project 2**: Multi-VM Application Stack (current)
3. 🔜 **Project 3**: Blue-Green Deployment with Packer
4. 🔜 **Project 4**: Auto-Healing MIG

**Enhancement Ideas:**
- Add Redis caching layer
- Implement database replication
- Add monitoring dashboard
- Implement CI/CD for application code
- Add integration tests
- Implement backup automation

## 🤝 Contributing

Contributions welcome! Please open issues or pull requests.

## 📄 License

MIT License - free for learning purposes.

---

**Happy Learning! 🚀**
