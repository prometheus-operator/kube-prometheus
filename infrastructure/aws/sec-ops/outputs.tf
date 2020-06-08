# Security Group
output "k8s_prometheus_sg_id" {
  value = module.k8s_prometheus.k8s_wk_sg_id
}
