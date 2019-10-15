resource "oci_core_instance" "DNS1" {
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "HW DNS 1"
  hostname_label      = "HW-DNS1"
  shape               = "${var.dns_instance_shape}"
  subnet_id	      = "${var.subnet_id}"

  source_details {
    source_type             = "image"
    source_id               = "${var.image_ocid}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data		= "${var.user_data}"
  }

  timeouts {
    create = "30m"
  }
}

resource "oci_core_instance" "DNS2" {
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "HW DNS 2"
  hostname_label      = "HW-DNS2"
  shape               = "${var.dns_instance_shape}"
  subnet_id           = "${var.subnet_id}"

  source_details {
    source_type             = "image"
    source_id               = "${var.image_ocid}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data           = "${var.user_data}"
  }

  timeouts {
    create = "30m"
  }
}
