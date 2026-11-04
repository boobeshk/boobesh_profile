data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Project   = "lab-eks-platform"
    ManagedBy = "terraform"
    Owner     = "boobesh-k"
  }
}

# Three-AZ VPC: private subnets for nodes, public subnets for load balancers.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 48)]

  # One NAT gateway keeps lab cost down; use one per AZ in production.
  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  eks_managed_node_groups = {
    # Baseline capacity for system pods and steady workloads.
    general = {
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 2
      max_size     = 5
      desired_size = 2

      labels = {
        workload = "general"
      }
    }

    # Cheaper burst capacity; only pods that tolerate the taint land here.
    spot = {
      instance_types = ["t3.large", "t3a.large", "m5.large"]
      capacity_type  = "SPOT"

      min_size     = 0
      max_size     = 5
      desired_size = 1

      labels = {
        workload = "spot"
      }

      taints = {
        spot = {
          key    = "lifecycle"
          value  = "spot"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }
}
