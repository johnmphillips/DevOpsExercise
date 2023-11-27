
output "backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}
output "frontend_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}
output "frontend_ip" {
  value = module.frontend_instance.public_ip
}
output "frontend_dns" {
  value = module.frontend_instance.public_dns
}
output "backend_ip" {
  value = module.backend_instance.public_ip
}
output "backend_dns" {
  value = module.backend_instance.public_dns
}
output "elasticsearch_ip" {
  value = module.elasticsearch_instance.public_ip
}
output "elasticsearch_dns" {
  value = module.elasticsearch_instance.public_dns
}
output "db_endpoint" {
  value = module.db.db_instance_endpoint
}
