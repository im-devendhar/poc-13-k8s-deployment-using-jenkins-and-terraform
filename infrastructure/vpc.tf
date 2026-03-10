# Creating VPC

resource "aws_vpc" "main"{
    cidr_block          = var.vpc_cidr
    enable_dns_support  = true
    enable_dns_hostnames = true

    tags = {
        Name = "eks_vpc"
    }
}

# Creating public subnets
resource "aws_subnet" "public_subnet_1"{
    vpc_id            = aws_vpc.main.id
    cidr_block        = var.public_subnet_1_cidr
    availability_zone = "${var.region}a"

    tags ={
        Name = "public_subnet_1"
    }
}

resource "aws_subnet" "public_subnet_2"{
    vpc_id            = aws_vpc.main.id
    cidr_block        = var.public_subnet_2_cidr
    availability_zone = "${var.region}b"

    tags ={
        Name = "public_subnet_2"
    }
}

#Creating private subnets
resource "aws_subnet" "private_subnet_1"{
    vpc_id            = aws_vpc.main.id
    cidr_block        = var.private_subnet_1_cidr
    availability_zone = "${var.region}a"

    tags ={
        Name = "private_subnet_1"
    }
}

resource "aws_subnet" "private_subnet_2"{
    vpc_id            = aws_vpc.main.id
    cidr_block        = var.private_subnet_2_cidr
    availability_zone = "${var.region}b"

    tags ={
        Name = "private_subnet_2"
    }
}


# Creating internet gateway for public subnets
resource "aws_internet_gateway" "igw"{
    vpc_id = aws_vpc.main.id
}

# Creating route table for public subnets
resource "aws_route_table" "public_rt"{
    vpc_id = aws_vpc.main.id
}

# Creating route for internet access in public route table
resource "aws_route" "public_internet"{
    route_table_id         = aws_route_table.public_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.igw.id
}

# Associating public subnets with public route table

resource "aws_route_table_association" "public_assoc_1"{
   subnet_id      = aws_subnet.public_subnet_1.id
   route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2"{
    subnet_id      = aws_subnet.public_subnet_2.id
    route_table_id = aws_route_table.public_rt.id
}

# Creating Elastic IP
resource "aws_eip" "nat_eip"{
    domain = "vpc"
}

# Creating nat gateway
resource "aws_nat_gateway" "nat_gw"{
    allocation_id = aws_eip.nat_eip.id
    subnet_id     = aws_subnet.public_subnet_1.id

}

resource "aws_route_table" "private_rt"{
    vpc_id = aws_vpc.main.id
}

resource "aws_route" "private_internet"{
    route_table_id = aws_route_table.private_rt.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
}

resource "aws_route_table_association" "private_assoc_1"{
    subnet_id = aws_subnet.private_subnet_1.id
    route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2"{
    subnet_id = aws_subnet.private_subnet_2.id
    route_table_id = aws_route_table.private_rt.id
}

