| Build                                                                                                                                                                                                                                             | Release                                                                                                                                                                                                                             | Extension                                                                                                                                                                              |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [![Build Status](https://dev.azure.com/shaykia/AzureDevOpsExtensions/_apis/build/status/shayki5.AzureDevOps-CreatePRTask?branchName=master)](https://dev.azure.com/shaykia/AzureDevOpsExtensions/_build/latest?definitionId=34&branchName=master) | [![Release Status](https://vsrm.dev.azure.com/shaykia/_apis/public/Release/badge/3372e1d4-189a-4d9e-aa4d-0cb86eff3c2e/1/2)](https://vsrm.dev.azure.com/shaykia/_apis/public/Release/badge/3372e1d4-189a-4d9e-aa4d-0cb86eff3c2e/1/2) | [![Extnesion](https://vsmarketplacebadge.apphb.com/version/ShaykiAbramczyk.CreatePullRequest.svg)](https://vsmarketplacebadge.apphb.com/version/ShaykiAbramczyk.CreatePullRequest.svg) |

## Azure DevOps Create Pull Request Task

An easy way to automatically create a Pull Request from your Build or Release Pipeline.

You can create a Pull Request to an Azure DevOps (Repos) repository or to a GitHub repository.

Support multi target branch (PR from one source branch to many target branches) and Draft Pull Request.

Choose title, description, reviewers and more.

## Prerequisites

- **The task currently only works on Windows machines.**

### For Azure DevOps Repository:

- You need to enable the "Allow scripts to access the OAuth token":

  - If you use the classic editor, go to the Agent job options, scroll down and check the checkbox "Allow scripts to acess the OAuth token":

    ![Oauth](https://i.imgur.com/trYBvHG.png)

  - If you use `yaml` build, you need to map the variable in the task:

    ```yaml
    env:
      System_AccessToken: $(System.AccessToken)
    ```

- You need to give permissions to the build user (in Microsoft hosted agnet is "Build Service (user-name)"):

  ![Permissions](https://i.imgur.com/Us401RM.png)

### For GitHub Repository:

- You need to create a GitHub service connection with Personal Access Token (PAT) - with `repo` permissions:

  ![GithubConnection](https://i.imgur.com/imWdnT7.png)

- To create the GitHub PAT go to https://github.com/settings/tokens/new

  ![PAT](https://i.imgur.com/AmKuY7d.png)

## Usage

**In the classic editor:**

![Task](https://i.imgur.com/6rKIgTK.png)

- **Git repository type**: Azure DevOps (Repos) or GitHub. When you choose GitHub you need to choose from the list the GitHub service connection (that use PAT authorization.)

- **GitHub Connection (authorized with PAT)**: When you choose GitHub in `Git repository type` you need to specify here the GitHub service connection.

- **Repository to use**: The method for selecting the Git repository:

  - In Azure DevOps: 'Current build' will use the repository for which the current build is configured. 'Select' will allow you to select an Azure DevOps Repository from your account.

  - In GitHub: The default will be `$(Build.Repository.Name)` - the current build repo, but you can select other repos from the drop down list.

- **Source branch name:** The source branch that will be merged. The default value is the build source branch - `$(Build.SourceBranch)`.

- **Target branch name:** The target branch name that the source branch will be merge to him. For example: `master`. Supports also multi target branch with `*`, for example: `test/*`.

- **Title:** The Pull Request title.

- **Description:** The Pull Request description. _(Optional)_.

- **Reviewers:** The Pull Request reviewers _(Optional)_ .
  <br> For Azure DevOps - one or more email address or team name separated by semicolon. For example: `test@test.com;MyTeamName`.

  <br> To make the reviewer required in Azure DevOps add 'req:' - e.g. `req:test@test.som`

  <br> For GitHub: one or more usernames separated by semicolon. For example: `user1;user2`.

- **Create Draft Pull Request**: If checekd the pull request will be a Draft Pull Request. (Default: false) <br> For Azure DevOps: see [here](https://docs.microsoft.com/en-us/azure/devops/repos/git/pull-requests?view=azure-devops#draft-pull-requests) more info. <br> For GitHub: see [here](https://github.blog/2019-02-14-introducing-draft-pull-requests/) more info.

- **Link Work Items**: If checked, all the work items that linked to the commits will be linked also to the PullRequest.

- **Set Auto Complete**: Only for Azure DevOps. If checekd the pull request will close once all branch policies are met.

  Complete options:

  - **Merge Strateg**: Specify the strategy used to merge the pull request during completion, see [here](https://devblogs.microsoft.com/devops/pull-requests-with-rebase/) more info.

    - Merge (No fast-forward) - `noFastForward` in yaml:

      A two-parent, no-fast-forward merge. The source branch is unchanged. This is the default behavior.

    - Squash commit - `squash` in yaml:

      Put all changes from the pull request into a single-parent commit.

    - Rebase and fast-forward - `rebase` in yaml:

      Rebase the source branch on top of the target branch HEAD commit, and fast-forward the target branch.
      The source branch is updated during the rebase operation.

    - Rebase and not fast-forward - `rebaseMerge` in yaml:

      Rebase the source branch on top of the target branch HEAD commit, and create a two-parent, no-fast-forward merge.
      The source branch is updated during the rebase operation.

  - **Delete Sourch Branch**: If true, the source branch of the pull request will be deleted after completion.
  - **Commit Message**: If set, this will be used as the commit message of the merge commit. if empty the default will be used.
  - **Complete Associated Work Items**: If true, we will attempt to transition any work items linked to the pull request into the next logical state (i.e. Active -> Resolved).

**In yaml piepline:**

```yaml
- task: CreatePullRequest@1
  inputs:
    repoType: Azure DevOps / GitHub
    githubEndpoint: 'my-github' # When you choose GitHub in `repoType` you need to specify here the GitHub service connection
    # When you choose GitHub in `repoType`
    # you can also put here each repo from your GitHub account, for example: user/myrepo
    # If you not specify anything the default will be "$(Build.Repository.Name)".
    githubRepository: # Default: $(Build.Repository.Name).
    # When you choose Azure DevOps in `repoType` - by default the PR will be for the current repository
    # You can select another repository from this project or onther project in your account
    # For this, specify `select` in `repositorySelectionMethod` and put the project id & git repo id
    repositorySelectionMethod: select
    projectId: '7fcdaf44-b831-4faa-b2fe-8k7a19a1d1af'
    gitRepositoryId: 'a743g5c4-85ec-4a4e-bf42-78964d551234'
    sourceBranch: '$(Build.SourceBranch)'
    targetBranch: 'master'
    title: 'Test'
    description: 'Test' # Optional
    reviewers: For Azure DevOps: 'test@test.com;MyTeam'. For GitHub: `username;username2` # Optional
    # To make the reviewer required in Azure DevOps add 'req:' - e.g. 'req:test@test.som'
    isDraft: false / true (Default: false)
    linkWorkItems: false / true (Default: true)
    autoComplete: false / true (Default: false)
    mergeStrategy: 'noFastForward (default) / squash / rebase / rebaseMerge'
    deleteSourch:  false / true (Default: false) # Optional
    commitMessage: 'Test Comment' # Optional
    transitionWorkItems:  false / true (Default: false) # Optional
  env:
    System_AccessToken: $(System.AccessToken)
```

## Known issue(s)

- ~~In Azure DevOps Server (TFS) you can't use reviewers. still can create a PR without it.~~ [Fixed in version 1.2.18]

## Release Notes

#### 1.2.130

- Now you can add also required reviewers. (for Azure DevOps).

#### 1.2.123

- Ability to choose other repos from your GitHub account. As a result, you can also create GitHub PR from a Release pipeline.

#### 1.2.89

- Throw a warning when there are no commits in the source branch, instaed of create a PR (for Azure DevOps).

#### 1.2.76

- Create PR for other repositories - not only for the current build repo (for Azure DevOps)

#### 1.2.48

- Link associated work items to the PR (for Azure DevOps)

#### 1.2.36

- Add complete options like Merge Strategy and more in auto completion (for Azure DevOps).

#### 1.2.30

- Support also a Team as reviewers (for Azure DevOps).

#### 1.2.24

- Set Auto Complete the Pull Request (for Azure DevOps).

#### 1.2.18

- Bug fix: Now you can add reviewers also in TFS 2018 and Azure DevOps Server 2019.

#### 1.2.15

- Draft Pull Request option.

#### 1.2.0

- Support also GitHub repositories!

#### 1.0.31

- Multi target branch (For example: `feature/*`)

#### 1.0.0

- First version.
