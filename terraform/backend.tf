terraform {
  backend "gcs" {
    bucket = "tftbk"
    prefix = "project-02-multi-vm-application-stack"
  }
}
