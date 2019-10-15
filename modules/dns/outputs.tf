output "dns1-ip" { value = "${data.oci_core_vnic.dns1_vnic.private_ip_address}" }
output "dns2-ip" { value = "${data.oci_core_vnic.dns2_vnic.private_ip_address}" }
