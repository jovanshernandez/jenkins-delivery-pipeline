// Delivery pipeline for delivery-app.
//
// Every build: unit tests -> image build -> image smoke test -> parallel validation
// (Kubernetes, Terraform x2, Ansible). On master: publish the image to ECR. With
// DEPLOY=true on master: plan the web stack, wait for a human approval, then apply
// and deploy with Ansible, which verifies the new build on the host.
//
// Controller requirements are listed in README.md ("Running it in Jenkins").

pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
    timeout(time: 60, unit: 'MINUTES')
  }

  parameters {
    booleanParam(name: 'DEPLOY', defaultValue: false,
      description: 'On master: plan the web stack, ask for approval, then deploy this build.')
  }

  environment {
    IMAGE_NAME       = 'delivery-app'
    AWS_REGION       = 'us-east-1'
    TF_IN_AUTOMATION = 'true'
    TF_INPUT         = '0'
    // ECR_REGISTRY (e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com) and
    // SSM_BUCKET come from the controller's global environment, not this file.
  }

  stages {
    stage('Prepare') {
      steps {
        script {
          env.GIT_SHA = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
          env.APP_VERSION = sh(script: 'git describe --tags --always', returnStdout: true).trim()
          env.IMAGE_TAG = "${env.GIT_SHA}-${env.BUILD_NUMBER}"
          currentBuild.description = "${env.IMAGE_NAME}:${env.IMAGE_TAG}"
        }
        sh 'mkdir -p reports'
      }
    }

    stage('Unit tests') {
      steps {
        sh '''
          python3 -m venv .venv
          .venv/bin/pip install --quiet -r app/requirements-dev.txt
          .venv/bin/python -m pytest app --junitxml=reports/junit.xml
        '''
      }
    }

    stage('Build image') {
      steps {
        sh '''
          docker build --pull \
            --build-arg APP_VERSION="$APP_VERSION" \
            --build-arg GIT_SHA="$GIT_SHA" \
            --build-arg BUILD_NUMBER="$BUILD_NUMBER" \
            --tag "$IMAGE_NAME:$IMAGE_TAG" \
            app
        '''
      }
    }

    stage('Image smoke test') {
      steps {
        sh 'scripts/container-smoke.sh "$IMAGE_NAME:$IMAGE_TAG" "$GIT_SHA"'
      }
    }

    stage('Validate') {
      failFast true
      parallel {
        stage('Kubernetes manifests') {
          steps {
            sh '''
              kubectl kustomize k8s/overlays/local > reports/k8s-local.yaml
              kubeconform -strict -summary reports/k8s-local.yaml
            '''
          }
        }

        stage('Terraform: jenkins') {
          steps {
            dir('terraform/jenkins') {
              sh '''
                terraform fmt -check -recursive
                terraform init -backend=false
                terraform validate
                terraform test
              '''
            }
          }
        }

        stage('Terraform: web') {
          steps {
            dir('terraform/web') {
              sh '''
                terraform fmt -check -recursive
                terraform init -backend=false
                terraform validate
                terraform test
              '''
            }
          }
        }

        stage('Ansible') {
          steps {
            dir('ansible') {
              sh '''
                ansible-playbook -i localhost, --syntax-check provision_jenkins.yaml
                ansible-playbook -i localhost, --syntax-check provision_web.yaml
              '''
            }
            sh 'ansible-lint'
          }
        }
      }
    }

    stage('Publish image') {
      when { branch 'master' }
      steps {
        // The controller's instance role may push to this one ECR repository;
        // docker authenticates through amazon-ecr-credential-helper.
        sh '''
          docker tag "$IMAGE_NAME:$IMAGE_TAG" "$ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
          docker push "$ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
        '''
      }
    }

    stage('Plan web stack') {
      when {
        allOf {
          branch 'master'
          expression { params.DEPLOY }
        }
      }
      steps {
        withCredentials([
          aws(credentialsId: 'aws-deploy', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'),
          file(credentialsId: 'tf-backend-web', variable: 'TF_BACKEND_CONFIG')
        ]) {
          dir('terraform/web') {
            sh '''
              terraform init -reconfigure -backend-config="$TF_BACKEND_CONFIG"
              terraform plan -out=tfplan
              terraform show -no-color tfplan > "$WORKSPACE/reports/web-plan.txt"
            '''
          }
        }
        archiveArtifacts artifacts: 'reports/web-plan.txt', fingerprint: true
      }
    }

    stage('Approve deploy') {
      when {
        allOf {
          branch 'master'
          expression { params.DEPLOY }
        }
      }
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          input message: "Deploy ${env.IMAGE_NAME}:${env.IMAGE_TAG}? Review reports/web-plan.txt first.",
                ok: 'Deploy',
                submitter: 'release-approvers'
        }
      }
    }

    stage('Deploy') {
      when {
        allOf {
          branch 'master'
          expression { params.DEPLOY }
        }
      }
      steps {
        withCredentials([
          aws(credentialsId: 'aws-deploy', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')
        ]) {
          // Apply exactly the plan that was approved.
          dir('terraform/web') {
            sh 'terraform apply tfplan'
          }
          // Ansible pulls the published image, restarts the unit and waits until
          // /version reports this commit before the stage can pass.
          dir('ansible') {
            sh '''
              ansible-galaxy collection install -r requirements.yml
              ansible-playbook provision_web.yaml \
                -e app_image="$ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG" \
                -e git_sha="$GIT_SHA" \
                -e app_version="$APP_VERSION" \
                -e build_number="$BUILD_NUMBER"
            '''
          }
        }
      }
    }
  }

  post {
    always {
      junit testResults: 'reports/junit.xml', allowEmptyResults: true
      archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
      sh 'docker image rm "$IMAGE_NAME:$IMAGE_TAG" || true'
    }
    success {
      echo "Pipeline passed for ${env.IMAGE_NAME}:${env.IMAGE_TAG}"
    }
    failure {
      echo "Pipeline failed at build ${env.BUILD_NUMBER}; see the stage log and archived reports."
    }
    cleanup {
      cleanWs()
    }
  }
}
