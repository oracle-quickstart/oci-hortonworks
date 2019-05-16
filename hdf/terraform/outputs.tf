output "AMBARI URL" { value = "https://${module.utility.public-ip}:9443/" }
output "DEPLOYMENT COMMAND" { value = "../scripts/hdf_deploy.sh ${module.utility.public-ip} ${var.availability_domain} ${var.master_node_count} ${var.master_instance_shape}" }
