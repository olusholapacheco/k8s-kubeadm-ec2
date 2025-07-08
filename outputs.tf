output "master_public_ip" {
  description = "Public IP of the master node"
  value       = aws_instance.bootstrap_k8s_master.public_ip
}

output "worker_public_ips" {
  description = "Public IPs of the worker nodes"
  value       = [for instance in aws_instance.bootstrap_k8s_worker : instance.public_ip]
}

