resource "oci_core_instance" "Utility" {
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "HW Utility-1"
  hostname_label      = "hw-utility-1"
  shape               = "${var.utility_instance_shape}"
  subnet_id           = "${var.subnet_id}"
  fault_domain	      = "FAULT-DOMAIN-3"

  source_details {
    source_type             = "image"
    source_id               = "${var.image_ocid}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data		= "${var.user_data}"
    ambari_server       = "${var.ambari_server}"
    ambari_version      = "${var.ambari_version}"
    hdp_version         = "${var.hdp_version}"
    hdp_utils_version   = "${var.hdp_utils_version}"
    worker_shape        = "${var.worker_shape}"
    block_volumes_per_worker = "${var.block_volumes_per_worker}"
    AD                  = "${var.AD}"
    deployment_type     = "${var.deployment_type}"
    worker_node_count   = "${var.worker_node_count}"
    cluster_name        = "${var.cluster_name}"
  }

  extended_metadata {
    ambari_setup        = "${var.ambari_setup}"
    hdp_deploy          = "${var.hdp_deploy}"
  }

  timeouts {
    create = "30m"
  }
}
