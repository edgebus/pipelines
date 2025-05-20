# EdgeBus Pipelines

This is `workspace` branch of a multi project repository based on [orphan](https://git-scm.com/docs/git-checkout#Documentation/git-checkout.txt---orphanltnew-branchgt) branches.

## How To Use

Choose CI/CD Platform to see related documentation:

- [Drone CI](https://github.com/edgebus/pipelines/tree/drone%23master)
- [Bitbucket Pipelines](https://github.com/edgebus/pipelines/tree/bitbucket%23master)
- [GitHub Actions](https://github.com/edgebus/pipelines/tree/github%23master)
- [GitLab Pipelines](https://github.com/edgebus/pipelines/tree/gitlab%23master)
- [Woodpecker CI](https://github.com/edgebus/pipelines/tree/woodpecker%23master)

## Development

### Setup Workspace

```shell
mkdir --parents ~/w-edgebus/pipelines
cd              ~/w-edgebus/pipelines

git init
git remote add origin ssh://git@github.com/edgebus/pipelines.git

git fetch --all --prune

git checkout workspace

git worktree add bitbucket.worktree               bitbucket#master
git worktree add drone.worktree                   drone#master
git worktree add github.worktree                  github#master
git worktree add gitlab.worktree                  gitlab#master
git worktree add woodpecker.worktree              woodpecker#master

code EdgeBus-Pipelines.code-workspace
```

### Notes

#### Add a new (platform) orphan branch

```shell
NEW_PLATFORM=...
#NEW_PLATFORM=bitbucket
#NEW_PLATFORM=woodpecker
git worktree add --orphan -b "${NEW_PLATFORM}#master" "${NEW_PLATFORM}.worktree"
(
    cd "${NEW_PLATFORM}.worktree" &&
    git commit --allow-empty -m "Initial Commit" &&
    git push origin "${NEW_PLATFORM}#master"
)

jq \
  --arg name "${NEW_PLATFORM}" \
  --arg path "${NEW_PLATFORM}.worktree" \
  '.folders += [{"name": $name, "path": $path }]' \
  EdgeBus-Pipelines.code-workspace \
| sponge EdgeBus-Pipelines.code-workspace
```
