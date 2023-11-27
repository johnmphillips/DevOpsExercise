
variable "ssh_key_name" {
  description = "Name of the SSH key used for ec2 instances"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR block for allowed SSH access"
  type        = string
}

