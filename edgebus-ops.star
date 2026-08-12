def step_factory__welcome(*, use_container):
  step = {
    "name": "welcome",
    "commands": [
      "echo \"Run on agent '$$(hostname -s)'\"",
      "touch .envvars",
      "env",
      "mount",
    ]
  }
  if use_container:
    step["image"] = "alpine:3.22"
  return step

# def step_factory__notify_failure_slack():
#   return {
#     "name": "notify-failure-slack",

#     "when": {
#       "status": [
#         "failure"
#       ]
#     }
#   }

def step_factory__notify_slack(stage_cfg, repo_ctx, build_ctx, *, use_container, name_suffix, notify_cfg, notify_status_cfg):
  # Спочатку намагаємося отримати канал з status секції, якщо не вийшло, то з основної секції
  slack_channel = None
  if (not is_none(notify_status_cfg)) and "channel" in notify_status_cfg:
    slack_channel = notify_status_cfg["channel"]
  if is_none(slack_channel) and "channel" in notify_cfg:
    slack_channel = notify_cfg["channel"]
  if is_none(slack_channel):
    fail("Slack channel is not defined in notification configuration for stage: " + stage_cfg["name"])

  # Спочатку намагаємося отримати канал з status секції, якщо не вийшло, то з основної секції
  header_template = notify_status_cfg["header_template"] if (not is_none(notify_status_cfg) and "header_template" in notify_status_cfg) else None
  header_template = notify_cfg["header_template"] if (is_none(header_template) and "header_template" in notify_cfg) else None

  # Спочатку намагаємося отримати канал з status секції, якщо не вийшло, то з основної секції
  content_templates = notify_status_cfg["content_templates"] if (not is_none(notify_status_cfg) and "content_templates" in notify_status_cfg) else None
  content_templates = notify_cfg["content_templates"] if (is_none(content_templates) and "content_templates" in notify_cfg) else None

  # Спочатку намагаємося отримати канал з status секції, якщо не вийшло, то з основної секції
  footer_template = notify_status_cfg["footer_template"] if (not is_none(notify_status_cfg) and "footer_template" in notify_status_cfg) else None
  footer_template = notify_cfg["footer_template"] if (is_none(footer_template) and "footer_template" in notify_cfg) else None

  custom_block = """{
    "blocks": [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": ":robot_face: Deployed DEPLOYMENT_ZONE DEPLOYMENT_INSTANCE",
                "emoji": true
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": "*Applications:*\\n<ECHO_SERVICE_URL|Echo Service>\\n<DOCUMENT_RENDERER_SERVICE_URL|Document Render Service>\\n<PRODUCT_VIEW_SERVICE_URL|Product View Service>"
                },
                {
                    "type": "mrkdwn",
                    "text": "*Maintenance:*\\n<KIBANA_URL|Kibana (logs)>\n<GRAFANA_URL|Grafana (metrics)>\\n<PGADMIN_URL|Postgres (pgAdmin)>"
                }
            ]
        }
    ]
}"""

  if use_container:
    step = {
      "image": "plugins/slack@sha256:dcc6e41ba1c052129631942815b352cdaef5a069a87ad232ff2c1962293b0067",
      "settings": {
        "channel": slack_channel,
        "username": "Drone CI",
        "icon_url": "https://unsplash.it/256/256/?random",
        "custom_block": custom_block,
      },
    }
    step["settings"]["webhook"] = {
      "from_secret": "SLACK_WEBHOOK"
    }
  else:
    step = {
      "commands": [
        "source ./.envvars",
        "echo \"$${SLACK_WEBHOOK}\" | base64",
        """
          docker run --rm --interactive \\\\
            --env PLUGIN_CHANNEL='""" + slack_channel + """' \\\\
            --env PLUGIN_USERNAME="Drone CI" \\\\
            --env PLUGIN_ICON_URL="https://miro.medium.com/v2/resize:fit:256/0*AqO_2lNemh_Fl9Gm.png" \\\\
            --env PLUGIN_WEBHOOK="$${PLUGIN_WEBHOOK}" \\\\
            --env PLUGIN_CUSTOM_BLOCK='""" + custom_block + """' \\\\
            --env DRONE_REPO_OWNER="$${DRONE_REPO_OWNER}" \\\\
            --env DRONE_REPO_NAME="$${DRONE_REPO_NAME}" \\\\
            --env DRONE_COMMIT_SHA="$${DRONE_COMMIT_SHA}" \\\\
            --env DRONE_COMMIT_BRANCH="$${DRONE_COMMIT_BRANCH}" \\\\
            --env DRONE_COMMIT_AUTHOR="$${DRONE_COMMIT_AUTHOR}" \\\\
            --env DRONE_COMMIT_AUTHOR_EMAIL="$${DRONE_COMMIT_AUTHOR_EMAIL}" \\\\
            --env DRONE_COMMIT_AUTHOR_AVATAR="$${DRONE_COMMIT_AUTHOR_AVATAR}" \\\\
            --env DRONE_COMMIT_AUTHOR_NAME="$${DRONE_COMMIT_AUTHOR_NAME}" \\\\
            --env DRONE_BUILD_NUMBER="$${DRONE_BUILD_NUMBER}" \\\\
            --env DRONE_BUILD_STATUS="$${DRONE_BUILD_STATUS}" \\\\
            --env DRONE_BUILD_LINK="$${DRONE_BUILD_LINK}" \\\\
            --env DRONE_TAG="$${DRONE_TAG}" \\\\
            plugins/slack@sha256:dcc6e41ba1c052129631942815b352cdaef5a069a87ad232ff2c1962293b0067
        """
      ],
    }
    step["environment"] = {
      "PLUGIN_WEBHOOK": {
        "from_secret": "SLACK_WEBHOOK"
      },
    }
  step["name"] = "notify-slack (" + name_suffix + ")"
  return step

# def step_factory__resolve_notification_slack_channel():
#   return {
#     "name": "resolve-notification-slack-channel",
#     "commands": [
#       shell_command__source_drone_env_if_exists,
#       """
#         if [ -n "$${NOTIFICATION_SLACK_CHANNEL}" ]; then
#           echo "THIS_NOTIFICATION_SLACK_CHANNEL=\\\\"$${NOTIFICATION_SLACK_CHANNEL}\\\\""   | tee -a .envvars
#         else
#           LOCAL_REPO_OWNER=$$(echo "$${DRONE_REPO_LINK}" | cut -d/ -f5)
#           echo "THIS_NOTIFICATION_SLACK_CHANNEL=\\\\"w-$${LOCAL_REPO_OWNER}\\\\""           | tee -a .envvars
#         fi
#       """
#     ]
#   }

def step_factory__setup_docker_registry(stage_cfg, repo_ctx, build_ctx):
  url_parts = repo_ctx.link.split("/")                                # parse https://gitea.example.org/octocat/hello-world
  repo_hostname = url_parts[2]                                        # -> gitea.example.org
  if "image_name" in stage_cfg:
    image_name = stage_cfg["image_name"]                                  # -> octocat/hello-world or docker://gitea.example.net/octocat/hello-world
    if not image_name.startswith("docker://"):
      registry_hostname = repo_hostname
      image_name = "docker://" + registry_hostname + "/" + image_name # -> docker://gitea.example.org/octocat/hello-world
    else:
      registry_hostname = image_name.split("/")[2]                    # -> gitea.example.net
  else:
    repo_path = url_parts[3] + "/" + url_parts[4]                     # -> octocat/hello-world
    registry_hostname = repo_hostname                                 # -> gitea.example.org
    image_name = "docker://" + registry_hostname + "/" + repo_path    # -> docker://gitea.example.org/octocat/hello-world
  registry_path = "/".join(image_name.split("/")[3:])                 # -> octocat/hello-world
  if "configuration" not in stage_cfg:
    registry_path = registry_path + "/snapshot"
  elif stage_cfg["configuration"] != "release":
    registry_path = registry_path + "/" + stage_cfg["configuration"]

  environment = {}
  commands = [
    # "echo 'image_name: " + image_name + "'",
    # "echo 'registry_hostname: " + registry_hostname + "'",
    # "echo 'registry_path: " + registry_path + "'",
    "[[ \"" + registry_hostname + "/" + registry_path + "\" =~ ^[0-9a-z\\\\._\\\\-]+(/[0-9A-Za-z\\\\._\\\\-]+)+$$ ]] || exit 61",
    "echo 'THIS_DOCKER_REGISTRY_HOSTNAME=\"" + registry_hostname + "\"' | tee -a .envvars",
    "echo 'THIS_DOCKER_REGISTRY_PATH=\"" + registry_hostname + "/" + registry_path + "\"' | tee -a .envvars",
  ]

  stage_auth = None if "auth" not in stage_cfg else stage_cfg["auth"]
  if(stage_auth != None):
    if "username" in stage_auth:
      if type(stage_auth["username"]) == "string":
        environment["DOCKER_USERNAME"] = stage_auth["username"]
      else:
        environment["DOCKER_USERNAME"] = {
          "from_secret": stage_auth["username"]["from_secret"]
        }
    else:
      environment["DOCKER_USERNAME"] = build_ctx.author_login
    if "token" in stage_auth:
      if type(stage_auth["token"]) == "string":
        environment["DOCKER_TOKEN"] = stage_auth["token"]
      else:
        environment["DOCKER_TOKEN"] = {
          "from_secret": stage_auth["token"]["from_secret"]
        }
    else:
      environment["DOCKER_TOKEN"] = {
        "from_secret": "DOCKER_REGISTRY_PUSH_TOKEN"
      }
    commands.append("if [ -z \"$${DOCKER_USERNAME}\" ]; then echo 'Docker user name is empty. Cannot continue. Define \"auth.username.from_secret\" in your pipeline or define default secret DOCKER_REGISTRY_PUSH_USERNAME.'; exit 1;  fi")
    commands.append("if [ -z \"$${DOCKER_TOKEN}\" ]; then echo 'Docker token is empty. Cannot continue. Define \"auth.token.from_secret\" in your pipeline or define default secret DOCKER_REGISTRY_PUSH_TOKEN.'; exit 2;  fi")
    commands.append("set -euo pipefail")
    commands.append("source ./.envvars")
    commands.append("echo \"DOCKER_USERNAME: $${THIS_DOCKER_REGISTRY_HOSTNAME}\"")
    commands.append("echo \"DOCKER_USERNAME: $${DOCKER_USERNAME}\"")
    commands.append("echo -n \"$${DOCKER_TOKEN}\" | docker login \"$${THIS_DOCKER_REGISTRY_HOSTNAME}\" --username \"$${DOCKER_USERNAME}\" --password-stdin")

  return {
    "name": "setup-docker-registry",
    "environment": environment,
    "commands": commands
  }

def step_factory__map_ci_variables(stage_configuration, *, use_container):
  step = {
    "name": "map-ci-variables",
    "commands": [
      "THIS__COMMIT__BRANCH=$$(echo \"$${DRONE_COMMIT_BRANCH}\" | cut -d# -f2)",
      "echo \"THIS__COMMIT__BRANCH=$${THIS__COMMIT__BRANCH}\" | tee -a .envvars",
      "echo \"THIS__COMMIT__REF=$${DRONE_COMMIT_SHA}\" | tee -a .envvars",
      "echo \"THIS__COMMIT__REF_SHORT=$$(echo $${DRONE_COMMIT_SHA} | head -c 8)\" | tee -a .envvars",
      "THIS__COMMIT__TAG=\"$${DRONE_TAG}\"",
      "echo \"THIS__COMMIT__TAG=$${THIS__COMMIT__TAG}\" | tee -a .envvars",
      "echo \"THIS__PIPELINE__ID=$${DRONE_BUILD_NUMBER}\" | tee -a .envvars",
      "echo \"THIS__PIPELINE__REF=$${DRONE_BUILD_LINK}\" | tee -a .envvars",
      "echo \"THIS__DOCKER_IMAGE_NAME=image-$${DRONE_BUILD_NUMBER}-$${DRONE_STAGE_NUMBER}-$${DRONE_STEP_NUMBER}\" | tee -a .envvars",
      "echo \"THIS__COMMIT__TIMESTAMP=$$(date --utc --date=\"@$${DRONE_BUILD_CREATED}\" +'%Y-%m-%dT%H:%M:%SZ')\" | tee -a .envvars",
      "echo \"THIS__PROJECT__REF=$${DRONE_REPO_LINK}\" | tee -a .envvars",
      """
        THIS__VERSION_RC_NUMBER=""
        if [ -n "$${THIS__COMMIT__TAG}" ]; then
          if echo -n "$${THIS__COMMIT__TAG}" | egrep -qe '-rc[0-9]+$$'; then
            THIS__VERSION_RC_NUMBER=$$(echo -n "$${THIS__COMMIT__TAG}" | sed 's/^.*-rc//')
          fi
        fi
      """,
      """
        if [ -n "$${THIS__COMMIT__TAG}" ]; then
          if [ -n "$${THIS__VERSION_RC_NUMBER}" ]; then
            THIS__VERSION=$$(echo -n "$${THIS__COMMIT__TAG}" | cut -d# -f2 | cut -d- -f1)
            THIS__VERSION_APPENDER="-rc$${THIS__VERSION_RC_NUMBER}""" + (("-" + stage_configuration) if stage_configuration != "release" else "") + """"
            THIS_IS_RELEASE_CANDIDATE="yes"
          else
            THIS__VERSION=$$(echo -n "$${THIS__COMMIT__TAG}" | cut -d# -f2)
            THIS__VERSION_APPENDER='""" + (("-" + stage_configuration) if stage_configuration != "release" else "") + """'
            THIS_IS_RELEASE_CANDIDATE="no"
            THIS__VERSION_MAJOR=$$(echo "$${THIS__VERSION}" | cut -d. -f1)
            THIS__VERSION_MAJOR_MINOR=$$(echo "$${THIS__VERSION}" | cut -d. -f1-2)
          fi
        else
          THIS__VERSION=""
          THIS__VERSION_APPENDER="-$${THIS__COMMIT__BRANCH}.$${THIS__COMMIT__REF_SHORT}""" + (("-" + stage_configuration) if stage_configuration != "release" else "") + """"
        fi
      """,
      "echo \"THIS__VERSION_RC_NUMBER=$${THIS__VERSION_RC_NUMBER}\"                                        | tee -a .envvars",
      "echo \"THIS__VERSION=$${THIS__VERSION}\"                                      | tee -a .envvars",
      "echo \"THIS_IS_RELEASE_CANDIDATE=$${THIS_IS_RELEASE_CANDIDATE}\"                    | tee -a .envvars",
      "echo \"THIS__VERSION_MAJOR=$${THIS__VERSION_MAJOR}\"                          | tee -a .envvars",
      "echo \"THIS__VERSION_MAJOR_MINOR=$${THIS__VERSION_MAJOR_MINOR}\"              | tee -a .envvars",
      "echo \"THIS__VERSION_APPENDER=$${THIS__VERSION_APPENDER}\"                            | tee -a .envvars",
    ]
  }
  if use_container:
    step["image"] = "alpine:3.22"
  return step

def stage_factory__build__cargo__package(stage_cfg, repo_ctx, build_ctx, *, stages_cfg):
  stage_configuration = "snapshot" if "configuration" not in stage_cfg else stage_cfg["configuration"]
  workspace_package = None if "workspace-package" not in stage_cfg else stage_cfg["workspace-package"]
  workspace_package_deps = None if "workspace-package-deps" not in stage_cfg else stage_cfg["workspace-package-deps"]
  registry = None if "registry" not in stage_cfg else stage_cfg["registry"]

  trigger_ref = []
  # Build from tag always
  if "ref_tag" in stage_cfg:
    trigger_ref.append("refs/tags/" + stage_cfg["ref_tag"])
  else:
    trigger_ref.append("refs/tags/**")
  # Build from branch only for non-release configurations
  if stage_configuration != "release":
    if "ref_branch" in stage_cfg:
      trigger_ref.append("refs/heads/" + stage_cfg["ref_branch"])
    elif not is_none(build_ctx.branch) and build_ctx.branch != "":
      trigger_ref.append("refs/heads/" + build_ctx.branch)

  if "#" in build_ctx.branch:
    branch = build_ctx.branch.split("#")[1]
  else:
    branch = build_ctx.branch

  steps = []
  depends_on = []

  steps.append(step_factory__welcome(use_container=True))

  # #steps.append(step_factory__setup_cargo_registry(stage_cfg, repo_ctx, build_ctx))
  setup_cargo_registry_step = {
    "name": "setup cargo",
    "image": "io.docker.registry-1.mirror.anurin.name/library/rust:1.97.1-alpine3.24",
    "commands": [
      "set -euo pipefail",
      "source ./.envvars",
      'export CARGO_HOME=$${DRONE_WORKSPACE}/.cargo-home',
      'mkdir $${CARGO_HOME}',
      'echo "CARGO_HOME=\\\\"$${CARGO_HOME}\\\\"" | tee -a .envvars',
      'echo "[registry]\nglobal-credential-providers = [\\\\"cargo:token\\\\"]" | tee $${CARGO_HOME}/config.toml',
      'echo $${CARGO_HOME}',
      'cat $${CARGO_HOME}/config.toml',
    ]
  }
  if not is_none(registry):
    for registry_item in registry:
      registry_name = registry_item["name"]
      registry_secret_ref = registry_item["secret-ref"]
      if (not is_none(registry_name) and (not is_none(registry_secret_ref))):
        secret_env_name = "CARGO_REGISTRIES_%s_TOKEN" % registry_name.upper()
        setup_cargo_registry_step["commands"].append('echo "export %s=\\\\"$${CARGO_REGISTRY_TOKEN}\\\\"" | tee -a .envvars' % secret_env_name)
        setup_cargo_registry_step["environment"] = {
          "CARGO_REGISTRY_TOKEN": {
            "from_secret": registry_secret_ref,
          },
        }
  steps.append(setup_cargo_registry_step)


  # steps.append(step_factory__map_ci_variables(stage_configuration, use_container=True))

  if (not is_none(workspace_package)):
    steps.append({
      "name": "read workspace version",
      "image": "io.ghcr.mirror.anurin.name/tomwright/dasel:3.11.2-alpine",
      "environment": {},
      "commands": [
        "set -euo pipefail",
        "VERSION=$$(cat Cargo.toml | dasel --in toml --out yaml 'workspace.package.version')",
        'echo "VERSION=\\\\"$${VERSION}-%s.$${CI_COMMIT_SHA}\\\\"" | tee -a .envvars' % branch,
      ]
    })
  else:
    steps.append({
      "name": "read package version",
      "image": "io.ghcr.mirror.anurin.name/tomwright/dasel:3.11.2-alpine",
      "environment": {},
      "commands": [
        "set -euo pipefail",
        "VERSION=$$(cat Cargo.toml | dasel --in toml --out yaml 'package.version')",
        'echo "VERSION=\\\\"$${VERSION}-%s.$${CI_COMMIT_SHA}\\\\"" | tee -a .envvars' % branch,
      ]
    })

  if (not is_none(workspace_package)) and (not is_none(workspace_package_deps)):
    for workspace_package_dep in workspace_package_deps:
      for check_depend_on_state in stages_cfg:
        if check_depend_on_state["name"] == workspace_package_dep:
          depends_on.append(workspace_package_dep)
          break
  #     steps.append({
  #       "name": "patch dep %s version" % workspace_package_dep,
  #       "image": "io.docker.registry-1.mirror.anurin.name/library/rust:1.97.1-alpine3.24",
  #       "environment": {
  #         "CARGO_REGISTRY_TOKEN": {
  #           "from_secret": registry_secret
  #         },
  #       },
  #       "commands": [
  #         "source ./.envvars",
  #         '(cd %s && cargo add %s@$${VERSION} --registry %s)' % (workspace_package, workspace_package_dep, registry_name),
  #       ]
  #     })

  if (not is_none(workspace_package)):
    update_script = """
import tomlkit
import sys

VERSION = sys.argv[1]

with open("Cargo.toml", "r", encoding="utf-8") as f:
    doc = tomlkit.parse(f.read())

if "workspace" in doc:
    if "package" in doc["workspace"] and "version" in doc["workspace"]["package"]:
        doc["workspace"]["package"]["version"] = VERSION

    if "dependencies" in doc["workspace"]:
        for dep in doc["workspace"]["dependencies"].values():
            if isinstance(dep, dict) and "version" in dep:
                dep["version"] = VERSION

with open("Cargo.toml", "w", encoding="utf-8") as f:
    f.write(tomlkit.dumps(doc))
"""
    steps.append({
      "name": "patch workspace version",
      "image": "io.docker.registry-1.mirror.anurin.name/library/python:3.14.7-alpine3.24",
      "commands": [
        "set -euo pipefail",
        "source ./.envvars",
        "pip3 install --break-system-packages tomlkit",
        "echo '%s' > /tmp/update_script.py" % update_script,
        "python3 /tmp/update_script.py $${VERSION}",
        "cat Cargo.toml",
      ]
    })
  else:
    steps.append({
      "name": "patch workspace version",
      "image": "io.docker.registry-1.mirror.anurin.name/library/python:3.14.7-alpine3.24",
      "environment": {},
      "commands": [
        "echo 'Not implemented yet'",
        "exit 1",
      ]
    })

  # fetch_step = {
  #   "name": "cargo fetch",
  #   "image": "io.docker.registry-1.mirror.anurin.name/library/rust:1.97.1-alpine3.24",
  #   # "volumes": [
  #   #   {
  #   #     "name": "cargo-registry-cache",
  #   #     "path": "/usr/local/cargo/registry"
  #   #   }
  #   # ],
  #   "commands": [
  #     "set -euo pipefail",
  #     "source ./.envvars",
  #     'cargo fetch',
  #     # '(cd "%s" && cargo fetch)' % workspace_package,
  #   ]
  # }
  # # if not is_none(registry_secret):
  # #   fetch_step["environment"] = {
  # #     "CARGO_REGISTRY_TOKEN": {
  # #       "from_secret": registry_secret
  # #     },
  # #   }
  # steps.append(fetch_step)

  if is_none(workspace_package):
    test_cmd = "cargo test"
    publish_cmd = 'cargo publish --allow-dirty'
  else:
    test_cmd = 'cargo test --package "%s"' % workspace_package
    publish_cmd = 'cargo publish --package "%s" --allow-dirty' % workspace_package
  # if not is_none(registry_name):
  #   publish_cmd = '%s --registry "%s"' % (publish_cmd, registry_name)

  steps.append({
    "name": "cargo test",
    "image": "io.docker.registry-1.mirror.anurin.name/library/rust:1.97.1-alpine3.24",
    "commands": [
      "set -euo pipefail",
      "source ./.envvars",
      test_cmd,
    ]
  })

  publish_step = {
    "name": "cargo publish",
    "image": "io.docker.registry-1.mirror.anurin.name/library/rust:1.97.1-alpine3.24",
    "environment": {},
    "commands": [
      "set -euo pipefail",
      "source ./.envvars",
      publish_cmd,
    ]
  }
  steps.append(publish_step)

  pipeline_stage =  {
    "kind": "pipeline",
    "name": stage_cfg["name"] if "name" in stage_cfg else stage_cfg["kind"],
    "type": "docker",
    "node": {
      "role": "builder",
      "builder.type": "docker",
    },
    "platform": {
      "os": "linux",
      "arch": "amd64"
    },
    "depends_on": depends_on,
    "trigger": {
      "ref": trigger_ref,
      "event": {
        "include":[ "custom", "push", "pull_request", "tag" ]
      }
    },
    "steps": steps
  }

  return pipeline_stage

def stage_factory__build__docker_host__image(stage_cfg, repo_ctx, build_ctx):
  stage_configuration = "snapshot" if "configuration" not in stage_cfg else stage_cfg["configuration"]
  dockerfile = "docker/Dockerfile" if "dockerfile" not in stage_cfg else stage_cfg["dockerfile"]

  trigger_ref = []
  # Build from tag always
  if "ref_tag" in stage_cfg:
    trigger_ref.append("refs/tags/" + stage_cfg["ref_tag"])
  else:
    trigger_ref.append("refs/tags/**")
  # Build from branch only for non-release configurations
  if stage_configuration != "release":
    if "ref_branch" in stage_cfg:
      trigger_ref.append("refs/heads/" + stage_cfg["ref_branch"])
    elif not is_none(build_ctx.branch) and build_ctx.branch != "":
      trigger_ref.append("refs/heads/" + build_ctx.branch)

  steps = []
  # steps.append({
  #   "name": "debug",
  #   "commands": [ 
  #     "echo \"trigger_ref: '" + ", ".join(trigger_ref) + "'\""
  #   ]
  # })
  steps.append(step_factory__welcome(use_container=False))
  steps.append(step_factory__setup_docker_registry(stage_cfg, repo_ctx, build_ctx))
  steps.append(step_factory__map_ci_variables(stage_configuration, use_container=False))
  steps.append({
    "name": "define_docker_image_tag_variables",
    "commands": [
      "source ./.envvars",
      """
        if [ -n "$${THIS__COMMIT__TAG}" ]; then
          if [ -n "$${THIS__VERSION_RC_NUMBER}" ]; then
            THIS__VERSION=$$(echo -n "$${THIS__COMMIT__TAG}" | cut -d# -f2 | cut -d- -f1)
            THIS__VERSION_APPENDER="-rc$${THIS__VERSION_RC_NUMBER}""" + (("-" + stage_configuration) if stage_configuration != "release" else "") + """"
            THIS__IMAGE_TAG__VERSION="$${THIS__VERSION}-rc$${THIS__VERSION_RC_NUMBER}"
          else
            THIS__VERSION=$$(echo -n "$${THIS__COMMIT__TAG}" | cut -d# -f2)
            THIS__VERSION_APPENDER='""" + (("-" + stage_configuration) if stage_configuration != "release" else "") + """'
            THIS__VERSION_MAJOR=$$(echo "$${THIS__VERSION}" | cut -d. -f1)
            THIS__VERSION_MAJOR_MINOR=$$(echo "$${THIS__VERSION}" | cut -d. -f1-2)
            THIS__IMAGE_TAG__VERSION="$${THIS__VERSION}"
            THIS__IMAGE_TAG__VERSION_MAJOR="$${THIS__VERSION_MAJOR}"
            THIS__IMAGE_TAG__VERSION_MAJOR_MINOR="$${THIS__VERSION_MAJOR_MINOR}"
          fi
        else
          THIS__IMAGE_TAG__VERSION=$$(echo "$${THIS__COMMIT__BRANCH}" | cut -d# -f2)
          THIS__VERSION=""
          THIS__VERSION_APPENDER="-$${THIS__IMAGE_TAG__VERSION}.$${THIS__COMMIT__REF_SHORT}""" + (("-" + stage_configuration) if stage_configuration != "release" else "") + """"
        fi
      """,
      "echo \"THIS__IMAGE_TAG__VERSION_MAJOR=$${THIS__IMAGE_TAG__VERSION_MAJOR}\"              | tee -a .envvars",
      "echo \"THIS__IMAGE_TAG__VERSION_MAJOR_MINOR=$${THIS__IMAGE_TAG__VERSION_MAJOR_MINOR}\"  | tee -a .envvars",
      "echo \"THIS__IMAGE_TAG__VERSION=$${THIS__IMAGE_TAG__VERSION}\"                          | tee -a .envvars",
    ]
  })
  steps.append({
        "name": "image-build",
        "commands": [
          "set -euo pipefail",
          "source ./.envvars",
          """docker build \\\\
              --no-cache \\\\
              --platform linux/amd64 \\\\
              --build-arg BUILD__CONFIGURATION='""" + stage_configuration + """' \\\\
              --build-arg BUILD__COMMIT__REF="$${THIS__COMMIT__REF}" \\\\
              --build-arg BUILD__COMMIT__TIMESTAMP="$${THIS__COMMIT__TIMESTAMP}" \\\\
              --build-arg BUILD__PIPELINE__REF="$${THIS__PIPELINE__REF}" \\\\
              --build-arg BUILD__PROJECT__REF="$${THIS__PROJECT__REF}" \\\\
              --build-arg BUILD__VERSION="$${THIS__VERSION}" \\\\
              --build-arg BUILD__VERSION_APPENDER="$${THIS__VERSION_APPENDER}" \\\\
              --build-arg BUILD__VERSION_RC_NUMBER="$${THIS__VERSION_RC_NUMBER}" \\\\
              --tag "$${THIS__DOCKER_IMAGE_NAME}" \\\\
              --file '""" + dockerfile + """' \\\\
              .
          """
        ]
      })
  steps.append({
        "name": "image-tags",
        "commands": [
          "source ./.envvars",
          """
            if [ -n "$${THIS__COMMIT__TAG}" ]; then
              if [ "$${THIS_IS_RELEASE_CANDIDATE}" == "no" ]; then
                echo "Create tag: $${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION_MAJOR_MINOR}"
                docker tag "$${THIS__DOCKER_IMAGE_NAME}" "$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION_MAJOR_MINOR}"
                echo "Create tag: $${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION_MAJOR}"
                docker tag "$${THIS__DOCKER_IMAGE_NAME}" "$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION_MAJOR}"
                echo "Create tag: $${THIS_DOCKER_REGISTRY_PATH}:latest"
                docker tag "$${THIS__DOCKER_IMAGE_NAME}" "$${THIS_DOCKER_REGISTRY_PATH}:latest"
              fi
            fi
          """,
          "echo \"Create tag: $${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}.$${THIS__COMMIT__REF}\"",
          "docker tag \"$${THIS__DOCKER_IMAGE_NAME}\" \"$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}.$${THIS__COMMIT__REF}\"",
          "echo \"Create tag: $${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}.$${THIS__COMMIT__REF_SHORT}\"",
          "docker tag \"$${THIS__DOCKER_IMAGE_NAME}\" \"$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}.$${THIS__COMMIT__REF_SHORT}\"",
          "echo \"Create tag: $${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}\"",
          "docker tag \"$${THIS__DOCKER_IMAGE_NAME}\" \"$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}\"",
        ]
      })
  steps.append({
        "name": "image-publish",
        "commands": [
          "source ./.envvars",
          """
            if [ -n "$${THIS__COMMIT__TAG}" ]; then
              if [ "$${THIS_IS_RELEASE_CANDIDATE}" == "no" ]; then
                docker push "$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION_MAJOR_MINOR}"
                docker push "$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION_MAJOR}"
                docker push "$${THIS_DOCKER_REGISTRY_PATH}:latest"
              fi
            fi
          """,
          "docker push \"$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}.$${THIS__COMMIT__REF}\"",
          "docker push \"$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}.$${THIS__COMMIT__REF_SHORT}\"",
          "docker push \"$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}\"",
        ]
      })

  pipeline_stage =  {
    "kind": "pipeline",
    "name": stage_cfg["name"] if "name" in stage_cfg else stage_cfg["kind"],
    "type": "exec",
    "node": {
      "role": "builder",
      "builder.type": "docker-host",
      "builder.docker-host.arch": "linux/amd64"
    },
    "platform": {
      "os": "linux",
      "arch": "amd64"
    },
    "trigger": {
      "ref": trigger_ref,
      "event": {
        "include":[ "custom", "push", "pull_request", "tag" ]
      }
    },
    "steps": steps
  }

  # pipeline_stage.update(
  #   {
  #     # "depends_on": [
  #     #   "sources-cleanliness",
  #     #   "database-integrity",
  #     # ],
  #     # "steps": [
  #     #   step_factory__resolve_notification_slack_channel(),
  #   }
  # )
  return pipeline_stage

def stage_factory__deploy__github_pages__image(stage, repo_ctx, build_ctx):
  steps = []
  steps.append(step_factory__welcome(use_container=True))

  pipeline_stage = {
    "kind": "pipeline",
    "name": stage["name"] if "name" in stage else stage["kind"],
    "type": "docker",
    "node": {
      "role": "builder",
      "builder.type": "docker",
    },
    "steps": steps,
  }

  if "depends_on" in stage:
    pipeline_stage["depends_on"] = stage["depends_on"]

  return pipeline_stage

def stage_factory__deploy__docker_swarm__sandbox(stage_cfg, repo_ctx, build_ctx, build_docker_image_stage):
  stage_configuration = "snapshot" if "configuration" not in stage_cfg else stage_cfg["configuration"]

  trigger_ref = []
  # Build from branch only for non-release configurations
  if stage_configuration != "release":
    if "ref_branch" in stage_cfg:
      trigger_ref.append("refs/heads/" + stage_cfg["ref_branch"])
    elif not is_none(build_ctx.branch) and build_ctx.branch != "":
      trigger_ref.append("refs/heads/" + build_ctx.branch)

  step_setup_docker_registry = find_item_by_name(build_docker_image_stage["steps"], "setup-docker-registry")
  step_define_docker_image_tag_variables = find_item_by_name(build_docker_image_stage["steps"], "define_docker_image_tag_variables")

  steps = []
  steps.append(step_factory__welcome(use_container=False))
  steps.append(step_setup_docker_registry)
  steps.append(step_factory__map_ci_variables(stage_configuration, use_container=False))
  steps.append(step_define_docker_image_tag_variables)
  steps.append({
    "name": "validate-branch-name",
    "commands":[
      "source ./.envvars",
      """
        if [ -n "$${THIS__COMMIT__TAG}" ]; then
          echo "This workflow may be used on work branches ONLY (but run on tag). To use this workflow your branch should follow naming convention described in https://gist.github.com/theanurin/4cdacd608d5a4f1ef9521225aa1a8b28" >&2
          exit 1
        else
          if echo "$${THIS__COMMIT__BRANCH}" | grep -Eq '#?main$'; then
            exit 0
          fi
          if echo "$${THIS__COMMIT__BRANCH}" | grep -Eq '#?master$'; then
            exit 0
          fi
          if echo "$${THIS__COMMIT__BRANCH}" | grep -Eq '#?dev$'; then
            exit 0
          fi
          if echo "$${THIS__COMMIT__BRANCH}" | grep -Eq '#?hotfix-[0-9]+\\\\.[0-9]+$'; then
            exit 0
          fi
          if echo "$${THIS__COMMIT__BRANCH}" | grep -Eq '#?issue-[0-9]+(-[a-z0-9]+)*$'; then
            exit 0
          fi
          echo "Wrong branch name '$${THIS__COMMIT__BRANCH}'. To use this workflow your branch should follow naming convention described in https://gist.github.com/theanurin/4cdacd608d5a4f1ef9521225aa1a8b28" >&2
          exit 1
        fi
      """
    ]
  })
  steps.append({
    "name": "define_deploy_variables",
    "commands":[
      "source ./.envvars",
      "set -euo pipefail",
      """
      THIS_ISSUE_ID=$$(echo "$${THIS__COMMIT__BRANCH}" | cut -d- -f-2)
      echo "THIS_ISSUE_ID=$${THIS_ISSUE_ID}" | tee -a .envvars
      """,
      """
      THIS_ISSUE_ID_SHORT=$$(echo "$${THIS_ISSUE_ID}" | tr "[:upper:]" "[:lower:]")
      echo "THIS_ISSUE_ID_SHORT=\"$${THIS_ISSUE_ID_SHORT}\"" | tee -a .envvars
      """,
      """
      THIS_DOCKER_SWARM_STACK_NAME="$${DRONE_REPO_NAMESPACE}-$${DRONE_REPO_NAME}-sandbox-$${THIS_ISSUE_ID_SHORT}"
      echo "THIS_DOCKER_SWARM_STACK_NAME=\\\\"$${THIS_DOCKER_SWARM_STACK_NAME}\\\\"" | tee -a .envvars
      """,
    ]
  })
  # steps.append({
  #   "name": "generate-secrets-directory",
  #   "environment":{
  #     "PGADMIN_DEFAULT_PASSWORD":{
  #     "from_secret": "DEVELOPMENT_PGADMIN_DEFAULT_PASSWORD"
  #       }
  #   },
  #   "commands":[
  #     "set -euo pipefail",
  #     "mkdir .secrets",
  #     "echo -n \"$${PGADMIN_DEFAULT_PASSWORD}\" > .secrets/PGADMIN_DEFAULT_PASSWORD"
  #   ]
  # })
  steps.append({
    "name": "ensure-image-pullable",
    "commands":[
      "source ./.envvars",
      "set -euox pipefail",
      # Pull image (to ensure image pullable)
      "docker pull --quiet \"$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}.$${THIS__COMMIT__REF}\"",
      # Remove image (to cleanup space)
      "docker image rm --no-prune \"$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}.$${THIS__COMMIT__REF}\"",
    ]
  })
  steps.append({
    "name": "deploy",
    "commands":[
      "source ./.envvars",
      "set -a",
      "source ./docker/stack/sandbox-stack.env",
      "set +a",
      "set -euo pipefail",
      "export DEPLOYMENT_SANDBOX_IMAGE=\"$${THIS_DOCKER_REGISTRY_PATH}:$${THIS__IMAGE_TAG__VERSION}.$${THIS__COMMIT__REF}\"",
      "export DEPLOYMENT_SANDBOX_PIPELINE_ID=\"$${THIS__PIPELINE__ID}\"",
      "export DEPLOYMENT_SANDBOX_PIPELINE_URL=\"$${THIS__PIPELINE__REF}\"",
      "export DEPLOYMENT_SANDBOX_BRANCH=\"$${THIS__COMMIT__BRANCH}\"",
      "export DEPLOYMENT_SANDBOX_COMMIT_SHA_SHORT=\"$${THIS__COMMIT__REF_SHORT}\"",
      "export DEPLOYMENT_SANDBOX_ISSUE_ID=\"$${THIS_ISSUE_ID_SHORT}\"",
      "DOCKER_VERSION_MAJOR=$$(docker version --format '{{.Server.Version}}' | cut -d. -f1)",
      "set -x",
      """
        case "$${DOCKER_VERSION_MAJOR}" in
          24|25|26|27)
            docker stack deploy --compose-file docker/stack/sandbox-stack.yaml                --prune --resolve-image always --with-registry-auth "$${THIS_DOCKER_SWARM_STACK_NAME}"
            ;;
          28)
            docker stack deploy --compose-file docker/stack/sandbox-stack.yaml --detach=false --prune --resolve-image always --with-registry-auth "$${THIS_DOCKER_SWARM_STACK_NAME}"
            ;;
          *)
            echo "Unsupported Docker version: $${DOCKER_VERSION_MAJOR}. Expected 24 or higher." >&2
            exit 1
            ;;
        esac
      """
    ]
  })
  # steps.append()

  tmp = {
    # "steps": [
    #   {
    #     "name": "notify-success-slack",
    #     "environment":{
    #       "PLUGIN_WEBHOOK":{
    #       "from_secret": "SLACK_WEBHOOK"
    #       }
    #     },
    #     "commands": [
    #       "source ./.envvars",
    #       """
    #       PLUGIN_CUSTOM_BLOCK=$$(
    #         cat .drone/sandbox-continuous-delivery.success-notification-template.json \\\\
    #           | sed "s~REPO_NAME~$${DRONE_REPO_NAME}~g" \\\\
    #           | sed "s~CHECKOUT_FRONTEND_URL~https://$${THIS_DOMAIN_PREFIX_CHECKOUT}.$${THIS_DOMAIN_SANDBOX_ROOT_1}~g" \\\\
    #           | sed "s~PGADMIN_URL~https://pgadmin-$${THIS_ISSUE_ID_SHORT}.$${THIS_DOMAIN_SANDBOX_ROOT_1}/browser/~g" \\\\
    #           | sed "s~REDIS_URL~https://redis-commander-$${THIS_ISSUE_ID_SHORT}.$${THIS_DOMAIN_SANDBOX_ROOT_1}/~g" \\\\
    #           | sed "s~WIREMOCK_URL~https://wiremock-$${THIS_ISSUE_ID_SHORT}.$${THIS_DOMAIN_SANDBOX_ROOT_1}/~g" \\\\
    #       )
    #       """,
    #       """
    #       docker run --rm --interactive \\\\
    #         --env PLUGIN_CHANNEL="$${THIS_NOTIFICATION_SLACK_CHANNEL}" \\\\
    #         --env PLUGIN_CUSTOM_BLOCK="$${PLUGIN_CUSTOM_BLOCK}" \\\\
    #         --env PLUGIN_USERNAME="Drone CI" \\\\
    #         --env PLUGIN_ICON_URL="https://miro.medium.com/v2/resize:fit:256/0*AqO_2lNemh_Fl9Gm.png" \\\\
    #         --env PLUGIN_WEBHOOK="$${PLUGIN_WEBHOOK}" \\\\
    #         --env DRONE_REPO_OWNER="$${DRONE_REPO_OWNER}" \\\\
    #         --env DRONE_REPO_NAME="$${DRONE_REPO_NAME}" \\\\
    #         --env DRONE_COMMIT_SHA="$${DRONE_COMMIT_SHA}" \\\\
    #         --env DRONE_COMMIT_BRANCH="$${DRONE_COMMIT_BRANCH}" \\\\
    #         --env DRONE_COMMIT_AUTHOR="$${DRONE_COMMIT_AUTHOR}" \\\\
    #         --env DRONE_COMMIT_AUTHOR_EMAIL="$${DRONE_COMMIT_AUTHOR_EMAIL}" \\\\
    #         --env DRONE_COMMIT_AUTHOR_AVATAR="$${DRONE_COMMIT_AUTHOR_AVATAR}" \\\\
    #         --env DRONE_COMMIT_AUTHOR_NAME="$${DRONE_COMMIT_AUTHOR_NAME}" \\\\
    #         --env DRONE_BUILD_NUMBER="$${DRONE_BUILD_NUMBER}" \\\\
    #         --env DRONE_BUILD_STATUS="$${DRONE_BUILD_STATUS}" \\\\
    #         --env DRONE_BUILD_LINK="$${DRONE_BUILD_LINK}" \\\\
    #         --env DRONE_TAG="$${DRONE_TAG}" \\\\
    #         plugins/slack@sha256:dcc6e41ba1c052129631942815b352cdaef5a069a87ad232ff2c1962293b0067
    #       """
    #     ],
    #       "when":{
    #         "status":[
    #         "success"
    #         ]
    #       },
    #   },
    # ],
  }

  pipeline_stage = {
    "kind": "pipeline",
    "name": stage_cfg["name"] if "name" in stage_cfg else stage_cfg["kind"],
    "type": "exec",
    "platform":{
      "os": "linux",
      "arch": "amd64"
    },
    "node": {
      "role": "deployer",
      "deployer.type": "docker-swarm-manager",
      "deployer.cluster": "development"
    },
    "trigger": {
      "ref": trigger_ref,
      "event": {
        "include":[ "custom", "push", "pull_request", "tag" ]
      }
    },
    "steps": steps,
  }

  pipeline_stage["depends_on"] = [build_docker_image_stage["name"]]

  return pipeline_stage

def main(ctx):
  pipeline_stages = []

  for stage_cfg in ctx.input.stages:
    if stage_cfg["kind"] == "build.cargo.package":
      pipeline_stage = stage_factory__build__cargo__package(stage_cfg, ctx.repo, ctx.build, stages_cfg = ctx.input.stages)
    elif stage_cfg["kind"] == "build.docker-host.image":
      pipeline_stage = stage_factory__build__docker_host__image(stage_cfg, ctx.repo, ctx.build)
    elif stage_cfg["kind"] == "deploy.github-pages.image":
      pipeline_stage = stage_factory__deploy__github_pages__image(stage_cfg, ctx.repo, ctx.build)
    elif stage_cfg["kind"] == "deploy.docker-swarm.sandbox":
      build_docker_image_stage = find_item_by_name(pipeline_stages, stage_cfg["build_image_stage"])
      pipeline_stage = stage_factory__deploy__docker_swarm__sandbox(stage_cfg, ctx.repo, ctx.build, build_docker_image_stage)
    else:
      pipeline_stage.update({
        "kind": "pipeline",
        "name": stage_cfg["name"],
        "type": "docker",
        "node": {
          "role": "builder",
          "builder.type": "docker"
        },
        "steps": [
          {
            "name": stage_cfg["field1"] + "-" + stage_cfg["field2"],
            "image": "alpine:latest",
            "commands": [ "echo \"" + command + "\"" for command in stage_cfg["commands"] ]
          }
        ]
      })
    steps = pipeline_stage["steps"]
    if "notify" in stage_cfg:
      stage_notify_cfg = stage_cfg["notify"]
      failure_when_condition = {
        "when": {
          "status": [
            "failure"
          ]
        }
      }
      if "slack" in stage_notify_cfg:
        notify_slack_cfg = stage_notify_cfg["slack"]
        if "success" in notify_slack_cfg:
          notify_status_cfg = notify_slack_cfg["success"]
          steps.append(step_factory__notify_slack(stage_cfg, ctx.repo, ctx.build, use_container=False, notify_cfg=notify_slack_cfg, notify_status_cfg=notify_status_cfg, name_suffix="success"))
        if "failure" in notify_slack_cfg:
          notify_status_cfg = notify_slack_cfg["failure"]
          steps.append(merge(
            step_factory__notify_slack(stage_cfg, ctx.repo, ctx.build, use_container=False, notify_cfg=notify_slack_cfg, notify_status_cfg=notify_status_cfg, name_suffix="failure"), 
            failure_when_condition
          ))

    pipeline_stages.append(pipeline_stage)

  return pipeline_stages

def is_none(value):
  # У Starlark немає прямої перевірки is None, як у Python.
  # Але ти можеш перевіряти на None (який у Starlark називається NoneType) через оператор порівняння == None або != None.
  return value == None

def find_item_by_name(items, name):
  # Шукаємо крок за його назвою
  for item in items:
    if "name" in item and item["name"] == name:
      return item
  return None  # Якщо крок не знайдено, повертаємо None

def merge(dict1, dict2):
  # Функція для об'єднання двох словників
  result = dict(dict1)  # Створюємо копію першого словника
  result.update(dict2)  # Оновлюємо його значеннями з другого словника
  return result