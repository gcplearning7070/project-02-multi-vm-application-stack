variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for VM instances"
  type        = string
  default     = "us-central1-a"
}

variable "web_vm_name" {
  description = "Name of the web tier VM instance"
  type        = string
  default     = "web-server"
}

variable "db_vm_name" {
  description = "Name of the database tier VM instance"
  type        = string
  default     = "db-server"
}

variable "machine_type" {
  description = "Machine type for VM instances"
  type        = string
  default     = "e2-micro"
}

variable "disk_size_gb" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 10
}

variable "disk_type" {
  description = "Type of the boot disk"
  type        = string
  default     = "pd-standard"
}

variable "image_family" {
  description = "OS image family"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "image_project" {
  description = "Project containing the OS image"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "appdb"
}

variable "db_user" {
  description = "PostgreSQL database user"
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "PostgreSQL database password (use strong password in production)"
  type        = string
  sensitive   = true
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 3000
}

variable "db_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "http_port" {
  description = "HTTP port for web server"
  type        = number
  default     = 80
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    project     = "gcp-learning"
    environment = "dev"
    managed_by  = "terraform"
    application = "multi-vm-stack"
  }
}
