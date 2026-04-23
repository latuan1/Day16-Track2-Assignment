output "alb_ip_address" {
  description = "External IP address of the Load Balancer"
  value       = google_compute_global_forwarding_rule.vllm_fwd.ip_address
}

output "endpoint_url" {
  description = "HTTP endpoint URL"
  value       = "http://${google_compute_global_forwarding_rule.vllm_fwd.ip_address}/health"
}

output "gpu_node_name" {
  description = "Name of the Compute Engine instance"
  value       = google_compute_instance.gpu_node.name
}

output "gpu_node_zone" {
  description = "Zone of the instance"
  value       = google_compute_instance.gpu_node.zone
}

output "gpu_private_ip" {
  description = "Private IP of the instance"
  value       = google_compute_instance.gpu_node.network_interface[0].network_ip
}

output "iap_ssh_command" {
  description = "Command to SSH into the instance via IAP"
  value       = "gcloud compute ssh ${google_compute_instance.gpu_node.name} --zone=${google_compute_instance.gpu_node.zone} --tunnel-through-iap"
}
