variable "prefix" {
  description = "Prefixe des ressources"
  type        = string
  default     = "tp-k3s"
}

variable "resource_group_name" {
  description = "Nom du resource group"
  type        = string
  default     = "tp-devops-rg"
}

variable "location" {
  description = "Region Azure"
  type        = string
  default     = "francecentral"
}

variable "vm_name" {
  description = "Nom de la VM"
  type        = string
  default     = "tp-k3s"
}

variable "vm_size" {
  description = "Taille de la VM"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Utilisateur SSH admin"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Chemin de la cle SSH publique"
  type        = string
  default     = "~/.ssh/id_ed25519_tp.pub"
}
