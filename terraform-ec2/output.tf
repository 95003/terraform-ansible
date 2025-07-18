output "instance_ips" {
  value = [for instance in aws_instance.indexer : instance.public_ip]
}

output "key_file_path" {
  value = local_file.private_key.filename
}
