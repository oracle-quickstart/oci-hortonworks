# Output the private and public IPs of the instance

output "WorkerShape" { 
  value = ["${var.WorkerInstanceShape}"]
}

output "BastionPublicIP" {
  value = ["${data.oci_core_vnic.bastion_vnic.public_ip_address}"]
}

output "UtilityPublicIP" {
  value = ["${data.oci_core_vnic.utility_node_vnic.public_ip_address}"]
}

output "Ambari Login" {
  value = ["http://${data.oci_core_vnic.utility_node_vnic.public_ip_address}:8080"]
}

output "Bastion SSH" { 
  value = ["ssh -i ~/.ssh/id_rsa opc@${data.oci_core_vnic.bastion_vnic.public_ip_address}"]
}
