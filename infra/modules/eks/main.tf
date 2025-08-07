# EKS Cluster IAM Role
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Additional IAM role policy for cluster service linked role
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  count      = var.cluster_version < "1.14" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}

# KMS Key for EKS secrets encryption (optional but recommended)
resource "aws_kms_key" "eks" {
  count                   = var.enable_secrets_encryption ? 1 : 0
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 10

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-eks-key"
    }
  )
}

resource "aws_kms_alias" "eks" {
  count         = var.enable_secrets_encryption ? 1 : 0
  name          = "alias/${var.cluster_name}-eks-key"
  target_key_id = aws_kms_key.eks[0].key_id
}

# EKS Cluster
resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = var.additional_security_group_ids
  }

  # Enable logging
  enabled_cluster_log_types = var.enabled_cluster_log_types

  # Encryption configuration
  dynamic "encryption_config" {
    for_each = var.enable_secrets_encryption ? [1] : []
    content {
      provider {
        key_arn = aws_kms_key.eks[0].arn
      }
      resources = ["secrets"]
    }
  }

  # Kubernetes network configuration
  dynamic "kubernetes_network_config" {
    for_each = var.cluster_service_ipv4_cidr != null ? [1] : []
    content {
      service_ipv4_cidr = var.cluster_service_ipv4_cidr
      ip_family         = var.cluster_ip_family
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy,
    aws_cloudwatch_log_group.cluster
  ]

  tags = var.tags
}

# CloudWatch Log Group for EKS cluster logs
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_in_days

  tags = var.tags
}

# OIDC Provider for IRSA (IAM Roles for Service Accounts)
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-oidc-provider"
    }
  )
}

# Node Group IAM Role
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Required policies for node group
resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# Additional policy for Systems Manager (optional)
resource "aws_iam_role_policy_attachment" "node_group_AmazonSSMManagedInstanceCore" {
  count      = var.enable_ssm ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node_group.name
}

# Security Group for EKS Nodes
resource "aws_security_group" "node_sg" {
  name_prefix = "${var.cluster_name}-node-sg"
  vpc_id      = var.vpc_id

  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description     = "Cluster to node communication"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "HTTPS from cluster"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id]
  }

  # Allow node port services (NodePort services)
  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = var.node_port_cidrs
  }

  # SSH access (optional)
  dynamic "ingress" {
    for_each = var.enable_ssh_access ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_access_cidrs
    }
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.cluster_name}-node-sg"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Additional Security Group for ALB Controller (if using AWS Load Balancer Controller)
resource "aws_security_group" "alb_controller" {
  count       = var.enable_alb_controller_sg ? 1 : 0
  name_prefix = "${var.cluster_name}-alb-controller-sg"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.cluster_name}-alb-controller-sg"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# Launch template for more advanced node configuration
resource "aws_launch_template" "node_group" {
  for_each = var.node_groups

  name_prefix   = "${var.cluster_name}-${each.key}-"
  image_id      = each.value.ami_id != null ? each.value.ami_id : data.aws_ssm_parameter.eks_ami_release_version[each.key].value
  instance_type = each.value.instance_types[0]

  vpc_security_group_ids = [
    aws_security_group.node_sg.id,
    aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
  ]

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    cluster_name        = var.cluster_name
    cluster_endpoint    = aws_eks_cluster.cluster.endpoint
    cluster_ca          = aws_eks_cluster.cluster.certificate_authority[0].data
    bootstrap_arguments = lookup(each.value, "bootstrap_extra_args", "")
  }))

  key_name = var.key_name

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.value.disk_size
      volume_type          = "gp3"
      iops                 = 3000
      throughput           = 125
      encrypted            = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      each.value.k8s_labels,
      {
        Name                                        = "${var.cluster_name}-${each.key}-node"
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      }
    )
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Get the latest EKS optimized AMI
data "aws_ssm_parameter" "eks_ami_release_version" {
  for_each = var.node_groups
  name     = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2/recommended/image_id"
}

# EKS Node Groups
resource "aws_eks_node_group" "node_groups" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = each.value.subnet_ids != null ? each.value.subnet_ids : var.subnet_ids

  capacity_type  = each.value.capacity_type
  instance_types = each.value.instance_types
  ami_type       = each.value.ami_type
  disk_size      = each.value.disk_size

  # Use launch template for advanced configuration
  launch_template {
    id      = aws_launch_template.node_group[each.key].id
    version = aws_launch_template.node_group[each.key].latest_version
  }

  scaling_config {
    desired_size = each.value.desired_capacity
    max_size     = each.value.max_capacity
    min_size     = each.value.min_capacity
  }

  update_config {
    max_unavailable_percentage = each.value.max_unavailable_percentage != null ? each.value.max_unavailable_percentage : null
    max_unavailable           = each.value.max_unavailable != null ? each.value.max_unavailable : 1
  }

  # Remote access configuration
  dynamic "remote_access" {
    for_each = var.key_name != null ? [1] : []
    content {
      ec2_ssh_key               = var.key_name
      source_security_group_ids = var.remote_access_source_sg_ids
    }
  }

  labels = merge(
    each.value.k8s_labels,
    {
      "node-group" = each.key
    }
  )

  dynamic "taint" {
    for_each = lookup(each.value, "taints", [])
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
    aws_launch_template.node_group
  ]

  tags = var.tags

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# EKS Addons
resource "aws_eks_addon" "addons" {
  for_each = var.cluster_addons

  cluster_name             = aws_eks_cluster.cluster.name
  addon_name               = each.key
  addon_version            = each.value.version
  resolve_conflicts        = each.value.resolve_conflicts
  service_account_role_arn = each.value.service_account_role_arn

  tags = var.tags

  depends_on = [aws_eks_node_group.node_groups]
}

# IAM Role for AWS Load Balancer Controller (if enabled)
resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0
  name  = "${var.cluster_name}-aws-load-balancer-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Policy for AWS Load Balancer Controller
resource "aws_iam_role_policy" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0
  name  = "${var.cluster_name}-aws-load-balancer-controller-policy"
  role  = aws_iam_role.aws_load_balancer_controller[0].id

  policy = file("${path.module}/aws-load-balancer-controller-policy.json")
}

# IAM Role for EBS CSI Driver (if enabled)
resource "aws_iam_role" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0
  name  = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count      = var.enable_ebs_csi_driver ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/Amazon_EBS_CSI_DriverPolicy"
  role       = aws_iam_role.ebs_csi_driver[0].name
}