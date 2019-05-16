output "block-volume-count" { value = "${ceil(((var.hdfs_usable_in_gbs*var.replication_factor)/var.data_blocksize_in_gbs)/var.instances)}" }
output "block-volume-size" { value = "${var.data_blocksize_in_gbs}" }
