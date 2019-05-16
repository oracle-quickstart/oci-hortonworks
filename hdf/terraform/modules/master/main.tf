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
    source_id               = "${var.InstanceImageOCID[var.region]}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data		= "${var.user_data}"
    ambari_server       = "${var.ambari_server}"
  }

  timeouts {
    create = "30m"
  }
}

