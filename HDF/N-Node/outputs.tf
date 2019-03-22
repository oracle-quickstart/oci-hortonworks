# Output the private and public IPs of the instance

output "INFO - BastionPublicIP" {
  value = ["${data.oci_core_vnic.bastion_vnic.public_ip_address}"]
}

output "INFO - UtilityPublicIP" {
  value = ["${data.oci_core_vnic.utility_node_vnic.public_ip_address}"]
}

output "2 - Ambari Login will be available later in setup process" {
  value = ["http://${data.oci_core_vnic.utility_node_vnic.public_ip_address}:8080"]
}

output "1 - Login to Bastion SSH" { 
  value = ["ssh -i ~/.ssh/id_rsa opc@${data.oci_core_vnic.bastion_vnic.public_ip_address}"]
}
