resource "oci_core_instance" "Worker" {
  count               = "${var.instances}"
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "HW Worker ${format("%01d", count.index+1)}"
  hostname_label      = "HW-Worker-${format("%01d", count.index+1)}"
  shape               = "${var.worker_instance_shape}"
  subnet_id           = "${var.subnet_id}"
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"

  source_details {
    source_type       = "image"
    source_id         = "${var.InstanceImageOCID[var.region]}"
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
// Block Volume Creation for Worker 

# Data Volumes for HDFS
resource "oci_core_volume" "WorkerDataVolume" {
  count		      = "${(var.instances * var.block_volumes_per_worker)}"
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "Hortonworks Worker ${format("%01d", (count.index / var.block_volumes_per_worker)+1)} HDFS Data ${format("%01d", (count.index%(var.block_volumes_per_worker))+1)}"
  size_in_gbs         = "${var.data_blocksize_in_gbs}"
}

resource "oci_core_volume_attachment" "WorkerDataAttachment" {
  count               = "${(var.instances * var.block_volumes_per_worker)}"  
  attachment_type = "iscsi"
  compartment_id  = "${var.compartment_ocid}"
  instance_id     = "${oci_core_instance.Worker.*.id[count.index/var.block_volumes_per_worker]}"
  volume_id       = "${oci_core_volume.WorkerDataVolume.*.id[count.index]}"
  device = "${var.data_volume_attachment_device[count.index%(var.block_volumes_per_worker)]}"
}

