pipeline {
  agent any

  environment {
    CLUSTER_NAME = 'eks-cluster'
    REGION       = 'us-east-1'
    SA_NAMESPACE = 'kube-system'
    SA_NAME      = 'aws-load-balancer-controller'
    POLICY_NAME  = 'AWSLoadBalancerControllerIAMPolicy'
    PATH = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
  }

  stages {

    stage('Install AWS CLI') {
      steps {
        sh '''
        set -eux
        if ! command -v unzip >/dev/null 2>&1; then
            sudo apt-get update -y
            sudo apt-get install -y unzip
        fi

        if ! command -v aws >/dev/null 2>&1; then
          curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
          unzip -q /tmp/awscliv2.zip -d /tmp
          sudo /tmp/aws/install
        fi
        aws --version
        '''
      }
    }

    stage('Configure AWS') {
      steps {
        withCredentials([
          string(credentialsId: 'AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'),
          string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
        ]) {
          sh '''
          set -eux
          aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
          aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
          aws configure set default.region "$REGION"
          aws sts get-caller-identity
          '''
        }
      }
    }

    stage('Install Terraform') {
      steps {
        sh '''
        set -eux
        if ! command -v terraform >/dev/null 2>&1; then
          sudo apt-get update -y
          sudo apt-get install -y gnupg software-properties-common wget
          wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
          echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
          sudo apt-get update -y
          sudo apt-get install -y terraform
        fi
        terraform -version
        '''
      }
    }

    stage('Install Docker') {
      steps {
        sh '''
        set -eux
        if ! command -v docker >/dev/null 2>&1; then
          sudo apt-get update -y
          sudo apt-get install -y docker.io
          sudo systemctl enable docker
          sudo systemctl start docker
        fi
        docker --version
        '''
      }
    }

    stage('Terraform Apply (Create EKS)') {
      steps {
        dir('infrastructure') {
          sh '''
          set -eux
          terraform init
          terraform validate
          terraform plan -out=tfplan
          terraform apply -auto-approve tfplan
          '''
        }
      }
    }

    stage('Wait for EKS Cluster') {
      steps {
        sh '''
        set -eux
        echo "Waiting for EKS cluster..."

        while true; do
          STATUS=$(aws eks describe-cluster \
          --name "$CLUSTER_NAME" \
          --region "$REGION" \
          --query "cluster.status" \
          --output text || echo "CREATING")

          echo "Cluster Status = $STATUS"

          if [ "$STATUS" = "ACTIVE" ]; then
            echo "Cluster Ready"
            break
          fi

          sleep 30
        done
        '''
      }
    }

    stage('Install eksctl') {
      steps {
        sh '''
        set -eux
        if ! command -v eksctl >/dev/null 2>&1; then
          curl -sL https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz | tar xz -C /tmp
          sudo mv /tmp/eksctl /usr/local/bin
        fi
        eksctl version
        '''
      }
    }

    stage('Install kubectl') {
      steps {
        sh '''
        set -eux
        if ! command -v kubectl >/dev/null 2>&1; then
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        fi
        kubectl version --client
        '''
      }
    }

    stage('Install Helm') {
      steps {
        sh '''
        set -eux
        if ! command -v helm >/dev/null 2>&1; then
          curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        fi
        helm version
        '''
      }
    }

    stage('Configure OIDC + IRSA') {
      steps {
        sh '''
        set -eux

        aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

        eksctl utils associate-iam-oidc-provider \
        --cluster "$CLUSTER_NAME" \
        --region "$REGION" \
        --approve

        POLICY_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME"

        if ! aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
          curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
          aws iam create-policy --policy-name "$POLICY_NAME" --policy-document file://iam-policy.json
        fi

        eksctl create iamserviceaccount \
        --cluster "$CLUSTER_NAME" \
        --namespace "$SA_NAMESPACE" \
        --name "$SA_NAME" \
        --attach-policy-arn "$POLICY_ARN" \
        --approve \
        --override-existing-serviceaccounts
        '''
      }
    }

    stage('Install AWS Load Balancer Controller') {
      steps {
        sh '''
        set -eux

        kubectl apply -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml

        helm repo add eks https://aws.github.io/eks-charts
        helm repo update

        VPC_ID=$(aws eks describe-cluster \
        --name "$CLUSTER_NAME" \
        --region "$REGION" \
        --query "cluster.resourcesVpcConfig.vpcId" \
        --output text)

        helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName="$CLUSTER_NAME" \
        --set serviceAccount.create=false \
        --set serviceAccount.name="$SA_NAME" \
        --set region="$REGION" \
        --set vpcId="$VPC_ID"

        kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
        '''
      }
    }

    stage('Deploy Application') {
      steps {
        sh '''
        set -eux
        kubectl apply -f k8s-manifests/namespace.yaml || true
        kubectl apply -f k8s-manifests/deployment.yaml
        kubectl apply -f k8s-manifests/service.yaml
        kubectl apply -f k8s-manifests/ingress.yaml || true

        kubectl get pods
        kubectl get svc
        '''
      }
    }

    stage('Get Application URL') {
      steps {
        sh '''
        set -eux
        HOST=$(kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' || true)

        if [ -n "$HOST" ]; then
          echo "Application URL:"
          echo "http://$HOST"
        else
          echo "Ingress hostname not ready yet."
        fi
        '''
      }
    }
  }

  post {
    always {
      sh '''
      echo "Cluster Status Report"
      kubectl get nodes || true
      kubectl get pods -A || true
      kubectl get svc -A || true
      kubectl get ingress -A || true
      '''
    }
  }
}
