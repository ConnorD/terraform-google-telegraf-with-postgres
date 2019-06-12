# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN OSS INFLUXDB CLUSTER
# As it is the OSS version, it will be a single-node cluster
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# SETUP PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------

provider "google" {
  version = "~> 2.7.0"
  region  = "${var.region}"
  project = "${var.project}"
}

provider "google-beta" {
  version = "~> 2.7.0"
  region  = "${var.region}"
  project = "${var.project}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE INFLUXDB OSS CLUSTER
# As we're running the OSS version, this is a single-node cluster
# ---------------------------------------------------------------------------------------------------------------------

module "influxdb_oss" {
  source = "../../modules/tick-instance-group"

  project = "${var.project}"
  region  = "${var.region}"

  // Size of an OSS setup is always 1
  size = 1

  data_volume_size        = 50
  data_volume_device_name = "influxdb"
  network_tag             = "${var.name}"
  name                    = "${var.name}"
  machine_type            = "${var.machine_type}"
  image                   = "${var.image}"
  startup_script          = "${data.template_file.startup_script.rendered}"
  network                 = "default"

  // For the example, we want to delete the data volume on 'terraform destroy'
  data_volume_auto_delete = "true"

  // To make testing easier, we're assigning public IPs to the node and allowing traffic from all IP addresses
  assign_public_ip = "true"

  // Use the custom InfluxDB SA
  service_account_email = "${module.service_account.email}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SERVICE ACCOUNT FOR THE CLUSTER INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

module "service_account" {
  source = "../../modules/influxdb-service-account"

  project      = "${var.project}"
  name         = "${var.name}-sa"
  display_name = "Service Account for InfluxDB OSS Server ${var.name}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE FIREWALL RULES FOR THE CLUSTER
# To make testing easier, we're allowing access from all IP addresses
# ---------------------------------------------------------------------------------------------------------------------

module "influxdb_firewall" {
  source = "../../modules/influxdb-firewall-rules"

  name_prefix = "${var.name}"
  network     = "default"
  project     = "${var.project}"
  target_tags = ["${module.influxdb_oss.network_tag}"]

  allow_api_access_from_cidr_blocks = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------------------------------------------------
# RENDER THE STARTUP SCRIPT THAT WILL RUN ON EACH NODE ON BOOT
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "startup_script" {
  template = "${file("${path.module}/startup-script.sh")}"

  vars {
    disk_mount_point = "/influxdb"
    disk_owner       = "influxdb"
  }
}
