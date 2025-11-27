# Copy this file to terraform.tfvars and update with your values
# terraform.tfvars is gitignored for security

project_id   = "leafy-glyph-479507-m4"
region       = "us-central1"
zone         = "us-central1-a"

# IMPORTANT: Change this password!
db_password  = "change-this-secure-password-123"

# Optional: Customize VM names
web_vm_name  = "web-server"
db_vm_name   = "db-server"

# Optional: Customize machine types
machine_type = "e2-micro"

# Optional: Customize database
db_name      = "appdb"
db_user      = "appuser"

labels = {
  project     = "gcp-learning"
  environment = "dev"
  managed_by  = "terraform"
  application = "multi-vm-stack"
}
