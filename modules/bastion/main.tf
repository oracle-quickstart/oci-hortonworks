resource "oci_core_instance" "Bastion" {
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "HW Bastion"
  hostname_label      = "HW-Bastion"
  shape               = "${var.bastion_instance_shape}"
  subnet_id	      = "${var.subnet_id}"

  source_details {
    source_type             = "image"
    source_id               = "${var.image_ocid}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data		= "${var.user_data}"
    ambari_server	= "${var.ambari_server}"
    ambari_version      = "${var.ambari_version}"
    hdp_version         = "${var.hdp_version}"
    hdp_utils_version   = "${var.hdp_utils_version}"
    deployment_type     = "${var.deployment_type}"
    cluster_name        = "${var.cluster_name}"
    AD                  = "${var.AD}"
    worker_node_count   = "${var.worker_node_count}"
  }

  timeouts {
    create = "30m"
  }
}
