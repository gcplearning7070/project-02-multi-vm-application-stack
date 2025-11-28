terraform {
  backend "gcs" {
    bucket = "gcp-tftbk2"
    prefix = "project-02-multi-vm-application-stack"
  }
}
