######################################
#IAM Policy
######################################
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "pods.eks.amazonaws.com"
        }

        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        }
      }
    ]
  })
}

######################################
#IAM Role
#####################################





#####################################
# Pod Identity Association
#####################################




#####################################
#Helm Release
#####################################



