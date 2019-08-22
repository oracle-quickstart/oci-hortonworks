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
    source_id         = "${var.image_ocid}"
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
// Block Volume Creation for Worker 

# Data Volumes for RAID cache

resource "oci_core_volume" "WorkerRAIDVolume1" {
  count               = "${var.instances}"
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "Cloudera Worker  ${format("%01d", count.index+1)} RAID cache"
  size_in_gbs         = "700"
}

resource "oci_core_volume_attachment" "WorkerRAIDAttachment1" {
  count           = "${var.instances}"
  attachment_type = "iscsi"
  instance_id     = "${oci_core_instance.Worker.*.id[count.index]}"
  volume_id       = "${oci_core_volume.WorkerRAIDVolume1.*.id[count.index]}"
  device = "/dev/oracleoci/oraclevdb"
}

resource "oci_core_volume" "WorkerRAIDVolume2" {
  count               = "${var.instances}"
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "Cloudera Worker  ${format("%01d", count.index+1)} RAID cache 2"
  size_in_gbs         = "700"
}

resource "oci_core_volume_attachment" "WorkerRAIDAttachment2" {
  count           = "${var.instances}"
  attachment_type = "iscsi"
  instance_id     = "${oci_core_instance.Worker.*.id[count.index]}"
  volume_id       = "${oci_core_volume.WorkerRAIDVolume2.*.id[count.index]}"
  device = "/dev/oracleoci/oraclevdc"
}

resource "oci_core_volume" "WorkerRAIDVolume3" {
  count               = "${var.instances}"
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "Cloudera Worker  ${format("%01d", count.index+1)} RAID cache 3"
  size_in_gbs         = "700"
}

resource "oci_core_volume_attachment" "WorkerRAIDAttachment3" {
  count           = "${var.instances}"
  attachment_type = "iscsi"
  instance_id     = "${oci_core_instance.Worker.*.id[count.index]}"
  volume_id       = "${oci_core_volume.WorkerRAIDVolume3.*.id[count.index]}"
  device = "/dev/oracleoci/oraclevdd"
}

resource "oci_core_volume" "WorkerRAIDVolume4" {
  count               = "${var.instances}"
  availability_domain = "${var.availability_domain}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "Cloudera Worker  ${format("%01d", count.index+1)} RAID cache 4"
  size_in_gbs         = "700"
}

resource "oci_core_volume_attachment" "WorkerRAIDAttachment4" {
  count           = "${var.instances}"
  attachment_type = "iscsi"
  instance_id     = "${oci_core_instance.Worker.*.id[count.index]}"
  volume_id       = "${oci_core_volume.WorkerRAIDVolume4.*.id[count.index]}"
  device = "/dev/oracleoci/oraclevde"
}

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
  instance_id     = "${oci_core_instance.Worker.*.id[count.index/var.block_volumes_per_worker]}"
  volume_id       = "${oci_core_volume.WorkerDataVolume.*.id[count.index]}"
  device = "${var.data_volume_attachment_device[count.index%(var.block_volumes_per_worker)]}"
}

