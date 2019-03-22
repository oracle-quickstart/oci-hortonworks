resource "oci_core_instance" "UtilityNode" {
  count               = "${var.UtilityNodeCount}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "HDF Utility ${count.index+1}"
  hostname_label      = "HDF-Utility-${count.index+1}"
  shape               = "${var.MasterInstanceShape}"
  subnet_id	      = "${oci_core_subnet.public.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    boot_volume_size_in_gbs = "${var.boot_volume_size}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(file("scripts/boot.sh"))}"
  }

  timeouts {
    create = "30m"
  }
}

resource "oci_core_instance" "MasterNode" {
  count		      = "${var.MasterNodeCount}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "HDF Master ${format("%01d", count.index+1)}"
  hostname_label      = "HDF-Master-${format("%01d", count.index+1)}"
  shape               = "${var.MasterInstanceShape}"
  subnet_id           = "${oci_core_subnet.private.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    boot_volume_size_in_gbs = "${var.boot_volume_size}"
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(file("scripts/boot.sh"))}"
  }

  timeouts {
    create = "30m"
  }
}

resource "oci_core_instance" "Bastion" {
  count               = "${var.BastionNodeCount}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "HDF Bastion${count.index+1}"
  hostname_label      = "HDF-Bastion${count.index+1}"
  shape               = "${var.BastionInstanceShape}"
  subnet_id           = "${oci_core_subnet.bastion.*.id[var.AD - 1]}"

  source_details {
    source_type = "image"
    source_id = "${var.InstanceImageOCID[var.region]}"
    boot_volume_size_in_gbs = "${var.boot_volume_size}"
  }

  create_vnic_details { 
    subnet_id = "${oci_core_subnet.bastion.*.id[var.AD - 1]}"
    skip_source_dest_check = true
  }

  metadata {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(file("scripts/bastion_boot.sh"))}"
  }

  timeouts {
    create = "30m"
  }
}

