# Docker Image Workflows

## Commits Naming Convention

| Git Branch Name           | DockerHub Image Tag  | Release GitHub Container Registry Image Tag  | Snapshot GitHub Container Registry Image Tag                                    |
| ------------------------- | -------------------- | -------------------------------------------- | ------------------------------------------------------------------------------- |
| `master`                  | -                    | -                                            | `master`, `master.c75f158d`, `master.c75f158d3c751112012dda5727daf0e380120cd1`  |
| `dev`                     | -                    | -                                            | `dev`, `dev.c75f158d`, `dev.c75f158d3c751112012dda5727daf0e380120cd1`           |

where `c75f158d3c751112012dda5727daf0e380120cd1` - commit SHA

## Tags Naming Convention

| Git Tag Name                           | DockerHub Image Tag            | Release GitHub Container Registry Image Tag                                                        | Snapshot GitHub Container Registry Image Tag                                                       |
| -------------------------------------- | ------------------------------ | -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `1.2.3-rc0`, `some-release-1.2.3-rc0`  | -                              | `1.2.3-rc0`, `1.2.3-rc0.c75f158d`, `1.2.3-rc0.c75f158d3c751112012dda5727daf0e380120cd1`            | `latest`, `1.2.3-rc0`, `1.2.3-rc0.c75f158d`, `1.2.3-rc0.c75f158d3c751112012dda5727daf0e380120cd1`  |
| `1.2.3`, `some-release-1.2.3`          | `latest`, `1`, `1.2`, `1.2.3`  | `latest`, `1`, `1.2`, `1.2.3`, `1.2.3.c75f158d`, `1.2.3.c75f158d3c751112012dda5727daf0e380120cd1`  | `latest`, `1`, `1.2`, `1.2.3`, `1.2.3.c75f158d`, `1.2.3.c75f158d3c751112012dda5727daf0e380120cd1`  |

where `c75f158d3c751112012dda5727daf0e380120cd1` - commit SHA
