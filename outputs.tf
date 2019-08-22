output "DEBUG INFO" { value = "Debug Logs for this deployment can be found on ${module.utility.public-ip} in /var/log/hortonworks-OCI-initialize.log and /var/log/hdp-OCI-deploy.log" }
output "AMBARI URL" { value = "https://${module.utility.public-ip}:9443/" }
