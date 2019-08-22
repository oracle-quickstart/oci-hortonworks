data "oci_core_vnic_attachments" "dns1_vnics" {
  compartment_id      = "${var.compartment_ocid}"
  availability_domain = "${var.availability_domain}"
  instance_id         = "${oci_core_instance.DNS1.id}"
}

data "oci_core_vnic" "dns1_vnic" {
  vnic_id = "${lookup(data.oci_core_vnic_attachments.dns1_vnics.vnic_attachments[0],"vnic_id")}"
}

data "oci_core_vnic_attachments" "dns2_vnics" {
  compartment_id      = "${var.compartment_ocid}"
  availability_domain = "${var.availability_domain}"
  instance_id         = "${oci_core_instance.DNS2.id}"
}

data "oci_core_vnic" "dns2_vnic" {
  vnic_id = "${lookup(data.oci_core_vnic_attachments.dns2_vnics.vnic_attachments[0],"vnic_id")}"
}
