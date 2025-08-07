# Basic cluster configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster and workers will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs where the EKS cluster (ENIs) will be provisioned along with the workers"
  type        = list(string)
}

# Cluster endpoint configuration
variable "endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_security_group_ids" {
  description = "List of additional, externally created security group IDs to attach to the cluster control plane"
  type        = list(string)
  default     = []
}

# Logging configuration
variable "enabled_cluster_log_types" {
  description = "A list of the desired control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_in_days" {
  description = "Number of days to retain log events. Default retention - 90 days"
  type        = number
  default     = 90
}

# Encryption configuration
variable "enable_secrets_encryption" {
  description = "Determines whether cluster secrets are encrypted"
  type        = bool
  default     = true
}

# Network configuration
variable "cluster_service_ipv4_cidr" {
  description = "The CIDR block to assign Kubernetes service IP addresses from"
  type        = string
  default     = null
}

variable "cluster_ip_family" {
  description = "The IP family used to assign Kubernetes pod and service addresses"
  type        = string
  default     = "ipv4"
  validation {
    condition     = contains(["ipv4", "ipv6"], var.cluster_ip_family)
    error_message = "Cluster IP family must be ipv4 or ipv6."
  }
}

# Node groups configuration
variable "node_groups" {
  description = "Map of EKS managed node group definitions to create"
  type = map(object({
    capacity_type               = string
    instance_types             = list(string)
    ami_type                   = optional(string, "AL2_x86_64")
    ami_id                     = optional(string)
    disk_size                  = optional(number, 20)
    desired_capacity           = number
    max_capacity              = number
    min_capacity              = number
    max_unavailable_percentage = optional(number)
    max_unavailable           = optional(number)
    k8s_labels                = optional(map(string), {})
    subnet_ids                = optional(list(string))
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    bootstrap_extra_args = optional(string, "")
  }))
  default = {}
}

# Security group configuration
variable "node_port_cidrs" {
  description = "List of CIDR blocks that can access node ports"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "enable_ssh_access" {
  description = "Enable SSH access to worker nodes"
  type        = bool
  default     = false
}

variable "ssh_access_cidrs" {
  description = "List of CIDR blocks that can SSH to worker nodes"
  type        = list(string)
  default     = []
}

variable "enable_alb_controller_sg" {
  description = "Create additional security group for ALB Controller"
  type        = bool
  default     = false
}

# Launch template configuration
variable "key_name" {
  description = "The key name to use for the instance"
  type        = string
  default     = null
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring for EC2 instances"
  type        = bool
  default     = false
}

variable "remote_access_source_sg_ids" {
  description = "Set of EC2 Security Group IDs to allow SSH access from on the worker nodes"
  type        = list(string)
  default     = []
}

# Add-ons configuration
variable "cluster_addons" {
  description = "Map of cluster addon configurations to enable for the cluster"
  type = map(object({
    version                  = optional(string)
    resolve_conflicts        = optional(string, "OVERWRITE")
    service_account_role_arn = optional(string)
  }))
  default = {
    coredns = {
      version = null
    }
    kube-proxy = {
      version = null
    }
    vpc-cni = {
      version = null
    }
  }
}

# IRSA (IAM Roles for Service Accounts) configuration
variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller IAM role"
  type        = bool
  default     = false
}

variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI Driver IAM role"
  type        = bool
  default     = false
}

variable "enable_ssm" {
  description = "Enable AWS Systems Manager access for worker nodes"
  type        = bool
  default     = false
}

# Common tags
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}