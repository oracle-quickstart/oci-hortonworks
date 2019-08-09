resource "oci_core_instance" "Master" {
  count               = "${var.instances}"
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "HW Master ${format("%01d", count.index+1)}"
  hostname_label      = "HW-Master-${format("%01d", count.index+1)}"
  shape               = "${var.master_instance_shape}"
  subnet_id           = "${var.subnet_id}"
  fault_domain	      = "FAULT-DOMAIN-${(count.index%3)+1}"

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
    deployment_type     = "${var.deployment_type}"
    cluster_name        = "${var.cluster_name}"
    AD                  = "${var.AD}"
    worker_node_count   = "${var.worker_node_count}"
  }

  timeouts {
    create = "30m"
  }
}

// Block Volume Creation for Master 

# Data Volume for /data (Name & SecondaryName)
resource "oci_core_volume" "MasterNNVolume" {
  count               = "${var.instances}"
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "Hortonworks Master ${format("%01d", count.index+1)} Journal Data"
  size_in_gbs         = "${var.nn_volume_size_in_gbs}"
}

resource "oci_core_volume_attachment" "MasterNNAttachment" {
  count           = "${var.instances}"
  attachment_type = "iscsi"
  instance_id     = "${oci_core_instance.Master.*.id[count.index]}"
  volume_id       = "${oci_core_volume.MasterNNVolume.*.id[count.index]}"
  device          = "/dev/oracleoci/oraclevdb"
}

