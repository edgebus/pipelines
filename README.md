# Pipelines (Drone)

Set of Drone's [pipeline templates](https://docs.drone.io/template/).

## Prerequisites

1. [ ] Install Drone CLI
2. [ ] Configure connectivity and authentication

See [CLI Reference](https://docs.drone.io/cli/install/)

## Get Started

### Setup EdgeBus Ops Drone Template

1. See `Account Settings` in Drone Dashboard to obtain `DRONE_SERVER` and `DRONE_TOKEN`
   ```shell
   export DRONE_SERVER=https://drone.infra.example.org
   export DRONE_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
1. [ ] Add `edgebus-ops.star` template inside your Drone organization
   ```shell
   DRONE_ORG=cvyntar
   drone template rm  --namespace "${DRONE_ORG}" --name edgebus-ops.star > /dev/null
   drone template add --namespace "${DRONE_ORG}" --name edgebus-ops.star --data @edgebus-ops.star
   ```
1. [ ] Use the template in your `.drone.yaml`
   ```yaml
   kind: template
   load: edgebus-ops.star
   data:
   stages:
     - kind: build.docker.npm
       run:
         - build
         - test
     - kind: build.docker-host.image
     - kind: deploy.github-pages
   ```

## Stage Kinds

### build.docker-host.image

Image tags are formatting from the repo commit hash/branch/tag:

| Commit hash                              | Branch                 | Tag                           | Result Image Tags                                                  |
| ---------------------------------------- | ---------------------- | ----------------------------- | ------------------------------------------------------------------ |
| fde0339b768ace15f47b93c1916add8e3ac05c11 | main                   | -                             | main.fde0339b768ace15f47b93c1916add8e3ac05c11, main.fde0339b, main |
| fde0339b768ace15f47b93c1916add8e3ac05c11 | some.orphan.branch#dev | -                             | dev.fde0339b768ace15f47b93c1916add8e3ac05c11, dev.fde0339b, dev    |
| fde0339b768ace15f47b93c1916add8e3ac05c11 | -                      | 0.0.1-rc01                    | dev.fde0339b768ace15f47b93c1916add8e3ac05c11, dev.fde0339b, dev    |
| fde0339b768ace15f47b93c1916add8e3ac05c11 | -                      | some.orphan.branch#0.0.1-rc01 | dev.fde0339b768ace15f47b93c1916add8e3ac05c11, dev.fde0339b, dev    |
| fde0339b768ace15f47b93c1916add8e3ac05c11 | -                      | 0.0.1                         | dev.fde0339b768ace15f47b93c1916add8e3ac05c11, dev.fde0339b, dev    |
| fde0339b768ace15f47b93c1916add8e3ac05c11 | -                      | some.orphan.branch#0.0.1      | dev.fde0339b768ace15f47b93c1916add8e3ac05c11, dev.fde0339b, dev    |

```yaml
kind: template
load: edgebus-ops.star
data:
  stages:
    - kind: build.docker-host.image
      #
      # (Optional)
      # Set pipeline stage name
      # Default: "build.docker-host.image"
      #
      #name: "image-snapshot"
      #
      # (Optional)
      # Set path to Dockerfile
      # Default: "docker/Dockerfile"
      #
      #dockerfile: "docker/Dockerfile"
      #
      # (Optional)
      # Set registry path
      # Default: "docker://<repo_host_port>/<repo_org>/<repo_name>"
      #
      #image_name: "docker://gitea.example.org:5001/octocat/hello-world"
      #image_name: "octocat/hello-world"
      #
      # (Optional)
      # Set build configuration (passed to docker build as BUILD__CONFIGURATION)
      # Default: "snapshot"
      #
      #configuration: "snapshot"
      #
      # (Optional)
      # Enable registry authentication
      #
      #auth:
      #  #
      #  # (Optional)
      #  # Set auth username (directly of from_secret)
      #  # Default: commit author login
      #  #
      #  #username: registry-writer-user
      #  #username:
      #  #  from_secret: DOCKER_REGISTRY_SNAPSHOT_PUSH_USERNAME
      #  #
      #  # (Optional)
      #  # Set auth token (directly of from_secret)
      #  # Default: read from secret "DOCKER_REGISTRY_PUSH_TOKEN"
      #  #
      #  #token: registry-writer-token
      #  #token:
      #  #  from_secret: DOCKER_REGISTRY_PUSH_TOKEN
```

### build.cargo.cli

```yaml
kind: template
load: edgebus-ops.star
data:
  stages:
    - kind: build.cargo.cli
      #
      # (Optional)
      # Set pipeline stage name
      # Default: "build.docker-host.image"
      #
      name: "image-snapshot"
      #
      # (Optional)
      # Set path to Dockerfile
      # Default: "docker/Dockerfile"
      #
      #dockerfile: "docker/Dockerfile"
      #
      # (Optional)
      # Set registry path
      # Default: "docker://<repo_host_port>/<repo_org>/<repo_name>"
      #
      #image_name: "docker://gitea.example.org:5001/octocat/hello-world"
      #image_name: "octocat/hello-world"
      #
      # (Optional)
      # Set build configuration (passed to docker build as BUILD__CONFIGURATION)
      # Default: "snapshot"
      #
      #configuration: "snapshot"
      #
      # (Optional)
      # Enable registry authentication
      #
      #auth:
      #  #
      #  # (Optional)
      #  # Set auth username (directly of from_secret)
      #  # Default: commit author login
      #  #
      #  #username: registry-writer-user
      #  #username:
      #  #  from_secret: DOCKER_REGISTRY_SNAPSHOT_PUSH_USERNAME
      #  #
      #  # (Optional)
      #  # Set auth token (directly of from_secret)
      #  # Default: read from secret "DOCKER_REGISTRY_PUSH_TOKEN"
      #  #
      #  #token: registry-writer-token
      #  #token:
      #  #  from_secret: DOCKER_REGISTRY_PUSH_TOKEN
```

### build.cargo.package

```yaml
kind: template
load: edgebus-ops.star
data:
  stages:
    - kind: build.cargo.package
      #
      # (Optional)
      # Set pipeline stage name
      # Default: "build.cargo.package"
      #
      name: "build.cargo.package"
      #
      # (Optional)
      # Set registry path
      # Default: "sparse+https://index.crates.io/"
      #
      #registry-name: "sparse+https://gitea.anurin.name/api/packages/octocat/cargo/"
      #
      # (Optional)
      # Enable registry authentication by set name of secret for auth token
      #
      #registry-secret: CARGO_REGISTRY_TOKEN
```

## Drone Restrictions

### Multiple templates in .drone.yml

Not supported (but desired) feature

```yaml
kind: template
load: deploy.yml
data:
  zone: uat
  service: dummy
  values:
    test: 123
---
kind: template
load: deploy.yml
data:
  zone: productions
  service: dummy
```

- [Support multiple templates from the same pipeline](https://drone.discourse.group/t/support-multiple-templates-from-the-same-pipeline/12255)
- [Allow using multiple templates per .drone.yml file](https://github.com/drone/proposal/issues/27)
