variable "region"{
    type = string
    default = "us-east-1"
}

variable "cluster_name"{
    default = "eks-cluster"
}

variable "instance_type"{
    default = "t3.small"
}

variable "desired_size"{
    type = number
    default= 2
}

variable "vpc_cidr"{
    default = "10.0.0.0/16"
}

variable "public_subnet_1_cidr"{
    default = "10.0.1.0/24"
}

variable "public_subnet_2_cidr"{
    default = "10.0.2.0/24"
}

variable "private_subnet_1_cidr"{
    default  = "10.0.3.0/24"
}

variable "private_subnet_2_cidr"{
    default = "10.0.4.0/24"
}
