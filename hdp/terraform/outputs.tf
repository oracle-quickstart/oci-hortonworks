output "AMBARI URL" { value = "https://${module.utility.public-ip}:9443/" }
output "DEPLOYMENT COMMAND" { value = "../scripts/hdp_deploy.sh ${module.utility.public-ip} ${var.availability_domain} ${var.worker_instance_shape} ${module.worker.block-volume-count} ${var.worker_node_count}" }
