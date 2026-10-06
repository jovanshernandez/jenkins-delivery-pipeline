# Operations notes

## Runtime endpoints

| Endpoint | Used by | Meaning |
| --- | --- | --- |
| `/health` | Docker `HEALTHCHECK`, Kubernetes liveness probe | The process is up and serving. |
| `/ready` | Kubernetes readiness probe | The app loaded; `checks.build_identity` is false if the image was built without a `GIT_SHA`. |
| `/version` | `scripts/smoke-test.sh`, Ansible deploy gate | `version`, `git_sha` and `build_number` baked in at build time. |
| `/metrics` | Prometheus | `http_requests_total`, `http_request_duration_seconds`, `app_build_info`, `app_uptime_seconds`. |

`app_build_info{git_sha="..."}` makes it possible to see which commit is serving traffic
from a dashboard, without shelling into the host.

## Promotion gates

A build can only reach the web host by passing each gate in order:

1. Unit tests pass (`pytest`, JUnit report archived).
2. The image builds and passes the container smoke test, which checks `/version`
   reports the commit being built.
3. All four validation branches pass: rendered manifests against the Kubernetes schemas,
   `terraform fmt`/`validate`/`test` for both stacks, Ansible syntax check and lint.
4. The build is on `master` (image pushed to ECR with an immutable `<sha>-<build>` tag).
5. `DEPLOY=true`, the web-stack plan is archived, and a member of `release-approvers`
   approves within 30 minutes.
6. Terraform applies exactly the approved plan file, then Ansible deploys the image and
   waits for `/version` on the host to report the new `git_sha`.

## Access

Neither host has a key pair or port 22 open. Use Session Manager:

```bash
aws ssm start-session --target <instance_id>

# Jenkins UI on localhost:8080 without opening the security group
aws ssm start-session --target <jenkins instance_id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
```

## Rollback

Image tags are immutable, so rolling back is redeploying an earlier tag:

```bash
cd ansible
SSM_BUCKET=<ssm_transfer_bucket output> ansible-playbook provision_web.yaml \
  -e app_image=<ECR_REGISTRY>/delivery-app:<previous sha>-<build> \
  -e git_sha=<previous sha>
```

The playbook fails unless the host reports the requested `git_sha` within 30 seconds.

## Bootstrapping order

1. `terraform/jenkins`: controller, ECR repository, SSM transfer bucket.
2. `ansible-playbook provision_jenkins.yaml` from an operator machine.
3. In Jenkins: install the plugins listed in the README, add the `aws-deploy` and
   `tf-backend-web` credentials, set `ECR_REGISTRY` and `SSM_BUCKET` as global
   environment variables, and create a Multibranch Pipeline for this repository.
4. Run the pipeline with `DEPLOY=true`. It creates the web stack on first apply.
