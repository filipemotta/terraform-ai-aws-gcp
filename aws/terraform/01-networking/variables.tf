variable "tags" {
  description = "Global tags injected by the provider default_tags block. Resources only add Name."
  type        = map(string)

  default = {
    "Project"   = "atlas"
    "Env"       = "sandbox"
    "region"    = "us-east-1"
    "ManagedBy" = "terraform"
  }
}
variable "assume_role" {
  description = "Region and fallback role for the provider. role_arn is used for any workspace not mapped in main.tf (fail closed: plan-only)."
  type = object({
    role_arn = string
    region   = string
  })

  default = {
    role_arn = "arn:aws:iam::123456789012:role/terraform-plan-readonly"
    region   = "us-east-1"
  }
}

variable "vpc" {
  description = "Network layout. Subnets are ordered lists consumed with count; index i of public and private share an AZ."
  type = object({
    name                     = string
    cidr_block               = string
    enable_dns_support       = bool
    enable_dns_hostnames     = bool
    internet_gateway_name    = string
    nat_gateway_name         = string
    public_route_table_name  = string
    private_route_table_name = string
    public_subnets = list(object({
      name                    = string
      cidr_block              = string
      availability_zone       = string
      map_public_ip_on_launch = bool
    }))
    private_subnets = list(object({
      name              = string
      cidr_block        = string
      availability_zone = string
    }))
  })

  default = {
    name                     = "vpc-atlas-useast1"
    cidr_block               = "10.10.0.0/16"
    enable_dns_support       = true
    enable_dns_hostnames     = true
    internet_gateway_name    = "igw-atlas-useast1"
    nat_gateway_name         = "nat-gateway-atlas-useast1"
    public_route_table_name  = "public-route-table-atlas-useast1"
    private_route_table_name = "private-route-table-atlas-useast1"
    public_subnets = [
      {
        name                    = "public-subnet-1"
        cidr_block              = "10.10.0.0/24"
        availability_zone       = "us-east-1a"
        map_public_ip_on_launch = true
      },
      {
        name                    = "public-subnet-2"
        cidr_block              = "10.10.1.0/24"
        availability_zone       = "us-east-1b"
        map_public_ip_on_launch = true
      },
    ]
    private_subnets = [
      {
        name              = "private-subnet-1"
        cidr_block        = "10.10.10.0/24"
        availability_zone = "us-east-1a"
      },
      {
        name              = "private-subnet-2"
        cidr_block        = "10.10.11.0/24"
        availability_zone = "us-east-1b"
      },
    ]
  }
}
