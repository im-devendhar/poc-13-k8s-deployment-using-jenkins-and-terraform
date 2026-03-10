pipeline {
  agent any

  environment {
    CLUSTER_NAME = 'eks-cluster'
    REGION       = 'us-east-1'
    SA_NAMESPACE = 'kube-system'
    SA_NAME      = 'aws-load-balancer-controller'
    POLICY_NAME  = 'AWSLoadBalancerControllerIAMPolicy'
    // Make sure /usr/local/bin is in PATH for tools we place there
    PATH = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
  }

  stages {

    stage('Install AWS CLI (v2) ') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          if ! command -v aws >/dev/null 2>&1; then
            curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
            unzip -q /tmp/awscliv2.zip -d /tmp
            sudo /tmp/aws/install
          fi
          aws --version
        '''
      }
    }

    stage('Configure AWS (Jenkins credentials)') {
      steps {
        withCredentials([
          string(credentialsId: 'aws_access_key_id',     variable: 'AWS_ACCESS_KEY_ID'),
          string(credentialsId: 'aws_secret_access_key', variable: 'AWS_SECRET_ACCESS_KEY')
        ]) {
          sh '''
            #!/bin/bash
            set -euxo pipefail
            aws configure set aws_access_key_id     "$AWS_ACCESS_KEY_ID"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
            aws configure set default.region        "$REGION"
            aws sts get-caller-identity --output text
          '''
        }
      }
    }

    stage('Install Terraform (HashiCorp APT)') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          if ! command -v terraform >/dev/null 2>&1; then
            sudo apt-get update -y
            sudo apt-get install -y gnupg software-properties-common wget
            if [ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]; then
              wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
            fi
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt-get update -y
            sudo apt-get install -y terraform
          fi
          terraform -version
        '''
      }
    }

    stage('Install Docker if missing') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          if ! command -v docker >/dev/null 2>&1; then
            sudo apt-get update -y
            sudo apt-get install -y ca-certificates curl gnupg lsb-release
            sudo install -m 0755 -d /etc/apt/keyrings || true
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update -y
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            sudo usermod -aG docker "$USER" || true
          fi
          docker --version || true
        '''
      }
    }

    stage('Terraform Init/Plan/Apply') {
      steps {
        dir('infrastructure') {
          sh '''
            #!/bin/bash
            set -euxo pipefail
            terraform init -upgrade
            terraform fmt -check || true
            terraform validate
            terraform plan -out=tfplan
            terraform apply -auto-approve tfplan
          '''
        }
      }
    }

    stage('Wait for EKS Cluster to be Ready') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail

          echo "Waiting for EKS cluster: ${CLUSTER_NAME} in ${REGION} to become ACTIVE..."

          # Max wait ~40 minutes (80 * 30s)
          MAX=80
          i=0
          while true; do
            STATUS=$(aws eks describe-cluster \
              --name "${CLUSTER_NAME}" \
              --region "${REGION}" \
              --query "cluster.status" \
              --output text || echo "PENDING")

            echo "Cluster Status = $STATUS"

            if [ "$STATUS" = "ACTIVE" ]; then
                echo "EKS Cluster is ACTIVE!"
                break
            fi

            i=$((i+1))
            if [ $i -ge $MAX ]; then
              echo "Timed out waiting for EKS cluster to become ACTIVE."
              exit 1
            fi

            echo "Still creating... sleeping for 30 seconds"
            sleep 30
          done

          # Optional: Wait until first nodegroup is ACTIVE (if any)
          echo "Checking if nodegroups are ready..."
          NG=$(aws eks list-nodegroups --cluster-name "${CLUSTER_NAME}" --region "${REGION}" --query "nodegroups[0]" --output text || echo "None")

          if [ "$NG" != "None" ] && [ -n "$NG" ]; then
            j=0
            while true; do
              NG_STATUS=$(aws eks describe-nodegroup \
                --cluster-name "${CLUSTER_NAME}" \
                --nodegroup-name "$NG" \
                --region "${REGION}" \
                --query "nodegroup.status" \
                --output text || echo "CREATING")

              echo "Nodegroup ($NG) Status = $NG_STATUS"

              if [ "$NG_STATUS" = "ACTIVE" ]; then
                echo "Nodegroup is ACTIVE!"
                break
              fi

              j=$((j+1))
              if [ $j -ge $MAX ]; then
                echo "Timed out waiting for nodegroup $NG to become ACTIVE."
                exit 1
              fi

              echo "Waiting for nodegroup... sleeping 30 sec"
              sleep 30
            done
          else
            echo "No managed nodegroups found yet (could be self-managed or created later)."
          fi

          echo "EKS Cluster + (optional) Nodegroup Ready!"
        '''
      }
    }

    stage('Install eksctl if missing') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          if ! command -v eksctl >/dev/null 2>&1; then
            ARCH=$(uname -m)
            curl -sSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_${ARCH}.tar.gz" -o /tmp/eksctl.tgz
            tar -xzf /tmp/eksctl.tgz -C /tmp
            sudo mv /tmp/eksctl /usr/local/bin/eksctl
          fi
          eksctl version
        '''
      }
    }

    stage('Install kubectl if missing') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          if ! command -v kubectl >/dev/null 2>&1; then
            KVER=$(curl -L -s https://dl.k8s.io/release/stable.txt)
            curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
          fi
          kubectl version --client=true
        '''
      }
    }

    stage('Install Helm if missing') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          if ! command -v helm >/dev/null 2>&1; then
            curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get_helm.sh
            chmod +x /tmp/get_helm.sh
            sudo /tmp/get_helm.sh
          fi
          helm version
        '''
      }
    }

    stage('OIDC + IRSA (idempotent)') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER_NAME}"

          # 1) OIDC
          eksctl utils associate-iam-oidc-provider --cluster "${CLUSTER_NAME}" --region "${REGION}" --approve

          # 2) IAM policy for AWS LBC
          POLICY_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/${POLICY_NAME}"
          if ! aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
            curl -fsSL https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json -o /tmp/iam-policy.json
            aws iam create-policy --policy-name "${POLICY_NAME}" --policy-document file:///tmp/iam-policy.json >/dev/null
          fi

          # 3) ServiceAccount with IRSA (safe to re-run)
          eksctl create iamserviceaccount \
            --cluster "${CLUSTER_NAME}" \
            --region  "${REGION}" \
            --namespace "${SA_NAMESPACE}" \
            --name "${SA_NAME}" \
            --attach-policy-arn "${POLICY_ARN}" \
            --approve \
            --override-existing-serviceaccounts

          kubectl -n "${SA_NAMESPACE}" get sa "${SA_NAME}" -o yaml | sed -n '1,60p'
        '''
      }
    }

    stage('Install/Upgrade AWS Load Balancer Controller') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER_NAME}"

          # CRDs
          kubectl apply -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml

          # Helm repo
          if ! helm repo list | awk '{print $1}' | grep -qx eks; then
            helm repo add eks https://aws.github.io/eks-charts
          fi
          helm repo update

          # VPC id
          VPC_ID=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${REGION}" --query "cluster.resourcesVpcConfig.vpcId" --output text)

          # Install/upgrade
          helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n "${SA_NAMESPACE}" \
            --set clusterName="${CLUSTER_NAME}" \
            --set serviceAccount.create=false \
            --set serviceAccount.name="${SA_NAME}" \
            --set region="${REGION}" \
            --set vpcId="${VPC_ID}"

          kubectl -n "${SA_NAMESPACE}" rollout status deploy/aws-load-balancer-controller --timeout=300s
        '''
      }
    }

    stage('Checkout application repo') {
      steps {
        checkout scm
      }
    }

    stage('Install yq (for YAML parsing)') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          if ! command -v yq >/dev/null 2>&1; then
            sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
            sudo chmod +x /usr/local/bin/yq
          fi
          yq --version
        '''
      }
    }

    stage('Apply Kubernetes Manifests') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          MAN_DIR="k8s-manifests"
          if [ ! -d "$MAN_DIR" ]; then
            echo "Folder $MAN_DIR not found. If your path is k8s-manifest/, change MAN_DIR variable."
            ls -la
            exit 1
          fi

          # Ensure namespace exists if you keep a separate namespace yaml
          kubectl apply -f "$MAN_DIR/namespace.yaml" || true

          kubectl apply -f "$MAN_DIR/deployment.yaml"
          kubectl apply -f "$MAN_DIR/service.yaml"
          kubectl apply -f "$MAN_DIR/ingress.yaml" || true

          # Rollout wait (reads name from deployment file)
          DEPLOY_NAME=$(yq '.metadata.name' "$MAN_DIR/deployment.yaml")
          if [ -n "$DEPLOY_NAME" ] && kubectl get deploy "$DEPLOY_NAME" >/dev/null 2>&1; then
            kubectl rollout status deploy/${DEPLOY_NAME} --timeout=180s || true
          else
            echo "Deployment name not found or resource missing; skipping rollout wait."
          fi

          kubectl get pods -o wide
          kubectl get svc  -o wide
          kubectl get ingress -o wide || true
        '''
      }
    }

    stage('Access Application URL') {
      steps {
        sh '''
          #!/bin/bash
          set -euxo pipefail
          if kubectl get ingress -o name >/dev/null 2>&1; then
            HOST=$(kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
            if [ -n "$HOST" ]; then
              echo "Application URL (if ready): http://${HOST}"
            else
              echo "Ingress found but hostname not yet assigned. It can take a few minutes."
            fi
          else
            echo "No Ingress found."
          fi
        '''
      }
    }
  }

  post {
    always {
      sh '''
        #!/bin/bash
        echo "=== Cluster status report ==="
        echo "--- Nodes ---"
        kubectl get nodes || true
        echo "--- Pods (all namespaces) ---"
        kubectl get pods -A || true
        echo "--- Services (all namespaces) ---"
        kubectl get svc -A || true
        echo "--- Ingresses (all namespaces) ---"
        kubectl get ingress -A || true
      '''
    }
  }
}
