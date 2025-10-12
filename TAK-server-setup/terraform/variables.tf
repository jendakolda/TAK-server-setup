variable "tenancy_ocid" {
  description = "The OCID of the tenancy"
  type        = string
}

variable "user_ocid" {
  description = "The OCID of the user"
  type        = string
}

variable "fingerprint" {
  description = "The fingerprint of the API key"
  type        = string
}

variable "private_key_path" {
  description = "The path to the private key file"
  type        = string
}

variable "region" {
  description = "The OCI region"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "compartment_ocid" {
  description = "The OCID of the compartment"
  type        = string
}

variable "ssh_public_key" {
  description = "The SSH public key for the instance"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDBCJcmALIj4xrnngRIuLD4DMztUKNDhbAVCTKJjBnUddCO0n3UCqk0Xh3xS69P/PcAV+ER2ZTRR0EzAGbbMoUzFO3necSfJ+n3u2UPtKygsIhrmkooj0FvU9lwhcMVjc9IVSOx+OO85XyhZSMgmMCviJKgrJoMwOEdneYpkKDx4f4WptALZmJPjXiTMS/5lRn9rQYcuKYlZe1NFpoBrIHCODo0AXCq3JWozIqL1vn6Mqu98U34mjZ7+SIrMqXrk9qMZ0AjGWx4xJDbEGbRjshahl1mI+BQGSPo01+sBC4kDa2aAfjqHOR7NAN5KNDn0/ABQiwnJ1BGlXBQF8h3ojVL ssh-key-2025-09-10"
}

variable "instance_shape" {
  description = "The shape of the compute instance"
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

variable "instance_name" {
  description = "The name of the compute instance"
  type        = string
  default     = "opentakserver"
}

variable "vcn_cidr" {
  description = "The CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "The CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}