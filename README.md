# GitHub Action Usage Guard

[![GitHub release (latest SemVer including pre-releases)](https://img.shields.io/github/v/release/nekofar/action-usage-guard?include_prereleases)](https://github.com/nekofar/action-usage-guard/releases)
[![GitHub Workflow Status (branch)](https://img.shields.io/github/actions/workflow/status/nekofar/action-usage-guard/prepare.yml)](https://github.com/nekofar/action-usage-guard/actions/workflows/prepare.yml)
[![GitHub](https://img.shields.io/github/license/nekofar/action-usage-guard)](https://github.com/nekofar/action-usage-guard/blob/master/LICENSE)
[![X (formerly Twitter) Follow](https://img.shields.io/badge/follow-%40nekofar-ffffff?logo=x&style=flat)](https://x.com/nekofar)
[![Donate](https://img.shields.io/badge/donate-nekofar.crypto-a2b9bc?logo=ko-fi&logoColor=white)](https://ud.me/nekofar.crypto)

A GitHub Action that cancels workflows if total account usage exceeds a defined threshold.

## Usage

```yaml
# This is the name of your GitHub Actions workflow
name: Main Workflow

# This workflow gets triggered on every push to your repository
on: [push]

# These are your workflow's jobs. Each job represents a process that your workflow will run.
jobs:
  # This is the job for usage guard
  guard:
    # Runs the guard job on the latest Ubuntu version
    runs-on: ubuntu-latest
    steps:
      # This step runs the Action Usage Guard
      - name: Run Action Usage Guard
        uses: nekofar/action-usage-guard@v1
        with:
          # GitHub access token for authentication.
          token: ${{ secrets.ACCESS_TOKEN }}
          # Defines the threshold for the usage guard.
          threshold: 70

  # This is the setup job
  setup:
    # The setup job requires the completion of the usage-guard job
    needs: [ guard ]
    # Runs the setup job on the latest Ubuntu version
    runs-on: ubuntu-latest
    steps:
      # This is a step to check out the code
      - name: Checkout code
        uses: actions/checkout@v3

      # This is a step with an example action
      - name: Another Step
        uses: actions/hello-world-docker-action@v1
        with:
          # This specifies who the action will 'greet'
          who-to-greet: 'GitHub Actions'
```

## Token

To make use of this action, a **Fine-grained Personal Access Token (PAT)** is essential. The PAT needs to be configured differently based on whether it is for a user account or an organization account.

If you use it for a user account, you need **Read** access to plan, **Read** access to metadata, and **Read** and **Write** access to actions.

If you use it for an organization, you need **Read** access to organization administration, **Read** access to metadata, and **Read** and **Write** access to actions.

Make sure to generate and handle the PAT securely, following the best practices for security. The access permissions can be managed by the user and organization administrators based on their security policies and requirements. If you require further assistance setting this up, please feel free to ask!

## Options

The configuration used in the GitHub Action workflow includes several options for customization. Each of these
configuration options has a specific use and can be tailored to suit your specific workflow needs. Below is a table
depicting these options:

| Option       | Description                                                                                          |
|--------------|------------------------------------------------------------------------------------------------------|
| `token`      | This is the actual GitHub access token for authentication.                                           |
| `threshold`  | (Optional) This defines the threshold value (1-100) for the usage guard action. The default is `70`. |

Each option should be carefully considered to ensure that your workflow proceeds as expected.

## Contributing

We value your input and help! If you're interested in contributing, please reference
our [Contributing Guidelines](./CONTRIBUTING.md). Contributions aren't just about code - any bug reports, feedback, or
documentation enhancements are welcomed. Thanks for helping to improve this project!
