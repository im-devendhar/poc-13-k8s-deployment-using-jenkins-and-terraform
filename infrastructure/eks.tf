resource "aws_eks_cluster" "eks"{
    name = var.cluster_name
    role_arn = aws_iam_role.eks_cluster_role.arn

    vpc_config{
        subnet_ids = [
            aws_subnet.private_subnet_1.id,
            aws_subnet.private_subnet_2.id
        ]
    }

    depends_on = [
        aws_iam_role_policy_attachment.eks_cluster_policy
    ]
}

resource "aws_eks_node_group" "node_group"{
    cluster_name = aws_eks_cluster.eks.name
    node_group_name = "${var.cluster_name}-node-group"
    node_role_arn = aws_iam_role.eks_node_role.arn

    subnet_ids = [
        aws_subnet.private_subnet_1.id,
        aws_subnet.private_subnet_2.id
    ]

    scaling_config{ 
        desired_size = var.desired_size
        max_size = 3
        min_size = 1
    }

    instance_types = [var.instance_type]

    depends_on = [
        aws_iam_role_policy_attachment.node_policy_1,
        aws_iam_role_policy_attachment.node_policy_2,
        aws_iam_role_policy_attachment.node_policy_3
    ]
}