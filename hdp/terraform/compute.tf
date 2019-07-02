module "bastion" {
	source	= "modules/bastion"
	instances = "1"
	region = "${var.region}"
	compartment_ocid = "${var.compartment_ocid}"
	subnet_id = "${module.network.bastion-id}" 
	availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain - 1],"name")}"
	image_ocid = "${var.InstanceImageOCID[var.region]}"
        ssh_private_key = "${var.ssh_private_key}"
	ssh_public_key = "${var.ssh_public_key}"
	bastion_instance_shape = "${var.bastion_instance_shape}" 
	user_data = "${base64encode(file("../scripts/boot.sh"))}"
	ambari_server = "hw-utility-1.public${var.availability_domain}.${module.network.vcn-dn}"
        ambari_version = "${var.ambari_version}"
        hdp_version = "${var.hdp_version}"
        hdp_utils_version = "${var.hdp_utils_version}"
	deployment_type = "${var.deployment_type}"
        cluster_name = "${var.cluster_name}"
}

module "utility" {
        source  = "modules/utility"
        instances = "1"
	region = "${var.region}"
	compartment_ocid = "${var.compartment_ocid}"
        subnet_id = "${module.network.public-id}"
	availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain - 1],"name")}"
	image_ocid = "${var.InstanceImageOCID[var.region]}"
	ssh_private_key = "${var.ssh_private_key}"
        ssh_public_key = "${var.ssh_public_key}"
        utility_instance_shape = "${var.utility_instance_shape}"
        user_data = "${base64encode(file("../scripts/ambari_utility_boot.sh"))}"
	ambari_server = "hw-utility-1.public${var.availability_domain}.${module.network.vcn-dn}"
	ambari_version = "${var.ambari_version}"
	hdp_version = "${var.hdp_version}"
	hdp_utils_version = "${var.hdp_utils_version}"
        worker_shape = "${var.worker_instance_shape}"
        block_volumes_per_worker = "${var.block_volumes_per_worker}"
        AD = "${var.availability_domain}"
        deployment_type = "${var.deployment_type}"
	worker_node_count = "${var.worker_node_count}"
	deployment_type = "${var.deployment_type}"
	cluster_name = "${var.cluster_name}"
	ambari_setup = "${base64gzip(file("../scripts/ambari_setup.sh"))}"
	hdp_deploy = "${base64gzip(file("../scripts/hdp_deploy.sh"))}"
}

module "master" {
        source  = "modules/master"
        instances = "${var.master_node_count}"
	region = "${var.region}"
	compartment_ocid = "${var.compartment_ocid}"
        subnet_id = "${module.network.private-id}"
        availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain - 1],"name")}"
	image_ocid = "${var.InstanceImageOCID[var.region]}"
        ssh_private_key = "${var.ssh_private_key}"
        ssh_public_key = "${var.ssh_public_key}"
        master_instance_shape = "${var.master_instance_shape}"
        user_data = "${base64encode(file("../scripts/boot.sh"))}"
	ambari_server = "hw-utility-1.public${var.availability_domain}.${module.network.vcn-dn}"
        ambari_version = "${var.ambari_version}"
        hdp_version = "${var.hdp_version}"
        hdp_utils_version = "${var.hdp_utils_version}"
	deployment_type = "${var.deployment_type}"
        cluster_name = "${var.cluster_name}"
}

module "worker" {
        source  = "modules/worker"
        instances = "${var.worker_node_count}"
	region = "${var.region}"
	compartment_ocid = "${var.compartment_ocid}"
        subnet_id = "${module.network.private-id}"
        availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain - 1],"name")}"
	image_ocid = "${var.InstanceImageOCID[var.region]}"
        ssh_private_key = "${var.ssh_private_key}"
        ssh_public_key = "${var.ssh_public_key}"
        worker_instance_shape = "${var.worker_instance_shape}"
	block_volumes_per_worker = "${var.block_volumes_per_worker}"	
	data_blocksize_in_gbs = "${var.data_blocksize_in_gbs}"
        user_data = "${base64encode(file("../scripts/boot.sh"))}"
	ambari_server = "hw-utility-1.public${var.availability_domain}.${module.network.vcn-dn}"
        ambari_version = "${var.ambari_version}"
        hdp_version = "${var.hdp_version}"
        hdp_utils_version = "${var.hdp_utils_version}"
	deployment_type = "${var.deployment_type}"
        cluster_name = "${var.cluster_name}"
}
