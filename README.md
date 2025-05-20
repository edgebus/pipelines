# Pipelines (GitHub)

## Usage

### As repository workflow

1. [ ] Copy a pipeline file `[pipeline].yml` to your repository at location `.github/workflows/[pipeline].yml`
1. [ ] Configure `env` section in `.github/workflows/[pipeline].yml` to setup your values
1. [ ] Commit and Push
1. [ ] Under your repository name, click Actions to see for launch the pipeline

### As workflow templates for your organization

1. [ ] Copy a pipeline files `[pipeline].yml` and `[pipeline].properties.json` to your organization's `.github` repository at location `workflow-templates/[pipeline].yml` and `workflow-templates/[pipeline].properties.json`. See guide [Creating workflow templates for your organization](https://docs.github.com/en/actions/sharing-automations/creating-workflow-templates-for-your-organization) for more details.
1. [ ] Adopt files `workflow-templates/[pipeline].yml` and `workflow-templates/[pipeline].properties.json` for your organization
1. [ ] Commit and Push
1. [ ] Follow guide [Using workflow templates](https://docs.github.com/en/actions/writing-workflows/using-workflow-templates) to use your workflows
