output "vm_public_ip" {
  description = "IP publique de la VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "vm_ssh_command" {
  description = "Commande SSH prete a l'emploi"
  value       = "ssh -i ${replace(var.ssh_public_key_path, ".pub", "")} ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "app_url" {
  description = "URL de l'application"
  value       = "http://${azurerm_public_ip.pip.ip_address}:30080"
}

output "grafana_url" {
  description = "URL de Grafana"
  value       = "http://${azurerm_public_ip.pip.ip_address}:30090"
}
