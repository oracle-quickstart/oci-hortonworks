module "bastion" {
	source	= "modules/bastion"
	instances = "1"
	region = "${var.region}"
	compartment_ocid = "${var.compartment_ocid}"
	subnet_id = "${module.network.bastion-id}" 
	availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain - 1],"name")}"
	ssh_keypath = "${var.ssh_keypath}" 
        ssh_private_key = "${var.ssh_private_key}"
	ssh_public_key = "${var.ssh_public_key}"
	private_key_path = "${var.private_key_path}"
	bastion_instance_shape = "${var.bastion_instance_shape}" 
	user_data = "${base64encode(file("../scripts/boot.sh"))}"
	ambari_server = "hw-utility-1.public${var.availability_domain}.${module.network.vcn-dn}"
}

module "utility" {
        source  = "modules/utility"
        instances = "1"
	region = "${var.region}"
	compartment_ocid = "${var.compartment_ocid}"
        subnet_id = "${module.network.public-id}"
	availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain - 1],"name")}"
	ssh_keypath = "${var.ssh_keypath}"
	ssh_private_key = "${var.ssh_private_key}"
        ssh_public_key = "${var.ssh_public_key}"
        private_key_path = "${var.private_key_path}"
        utility_instance_shape = "${var.utility_instance_shape}"
        user_data = "${base64encode(file("../scripts/boot_ambari.sh"))}"
	ambari_server = "hw-utility-1.public${var.availability_domain}.${module.network.vcn-dn}"
}

module "master" {
        source  = "modules/master"
        instances = "${var.master_node_count}"
	region = "${var.region}"
	compartment_ocid = "${var.compartment_ocid}"
        subnet_id = "${module.network.private-id}"
        availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain - 1],"name")}"
	ssh_keypath = "${var.ssh_keypath}"
        ssh_private_key = "${var.ssh_private_key}"
        ssh_public_key = "${var.ssh_public_key}"
        private_key_path = "${var.private_key_path}"
        master_instance_shape = "${var.master_instance_shape}"
        user_data = "${base64encode(file("../scripts/boot.sh"))}"
	ambari_server = "hw-utility-1.public${var.availability_domain}.${module.network.vcn-dn}"
}

