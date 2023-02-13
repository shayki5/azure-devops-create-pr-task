| Build                                                                                                                                                                                                                                             | Extension                                                                                                                                                                              |
| :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [![Build Status](https://dev.azure.com/shaykia/AzureDevOpsExtensions/_apis/build/status/shayki5.AzureDevOps-CreatePRTask?branchName=master)](https://dev.azure.com/shaykia/AzureDevOpsExtensions/_build/latest?definitionId=34&branchName=master) | [![Extension](https://vsmarketplacebadge.apphb.com/version/ShaykiAbramczyk.CreatePullRequest.svg)](https://vsmarketplacebadge.apphb.com/version/ShaykiAbramczyk.CreatePullRequest.svg) |

## Azure DevOps Create Pull Request Task

An easy way to automatically create a Pull Request from your Build (UI or YAML) or Release Pipeline.

You can create a Pull Request to an Azure DevOps (Repos) repository or to a GitHub repository.

Support multi target branch (PR from one source branch to many target branches) and Draft Pull Request.

Choose title, description, reviewers, tags and more.

[Get the extension](https://marketplace.visualstudio.com/items?itemName=ShaykiAbramczyk.CreatePullRequest) from the Azure DevOps marketplace.

## Prerequisites

- **The task currently only works on Windows machines.**

### For Azure DevOps Repository:

- You need to give permissions to the build users:

  In Microsoft hosted agent is "Build Service (user-name)" and "Project Collection Build Service (Project)"
  (Sometimes the last only show up if you type the UUID (8837...) on "Search for user or groups".)

  ![Permissions](https://i.imgur.com/Us401RM.png)
  
  **If you want to use Bypass you need to give also the permisison "Bypass policies when completing pull requests"**

### For GitHub Repository:

- You need to create a GitHub service connection with Personal Access Token (PAT) - with `repo` permissions:

  ![GithubConnection](https://i.imgur.com/imWdnT7.png)

- To create the GitHub PAT go to https://github.com/settings/tokens/new

  ![PAT](https://i.imgur.com/AmKuY7d.png)

## Usage

**In the classic editor:**

![Task](https://i.imgur.com/VhVzCJ2.png)

- **Git repository type**: Azure DevOps (Repos) or GitHub. When you choose GitHub you need to choose from the list the GitHub service connection (that use PAT authorization.)

- **GitHub Connection (authorized with PAT)**: When you choose GitHub in `Git repository type` you need to specify here the GitHub service connection.

- **Repository to use**: The method for selecting the Git repository:

  - In Azure DevOps: 'Current build' will use the repository for which the current build is configured. 'Select' will allow you to select an Azure DevOps Repository from your account.

  - In GitHub: The default will be `$(Build.Repository.Name)` - the current build repo, but you can select other repos from the drop down list.

- **Is Forked Repository:** [For Azure DevOps] If checked, it means the source branch it from a forked repository and not from the original. the target repo will be the currnet build repo.

- **Source branch name:** The source branch that will be merged. The default value is the build source branch - `$(Build.SourceBranch)`.

- **Target branch name:** The target branch name that the source branch will be merge to him. For example: `master`.
  <br> Supports also multi target branch with `*` - for example: `test/*`, or with `;` - for example: `master;test`.

- **Title:** The Pull Request title. You can use the token [BRANCH_NAME] to dynamically reuse the current target branch name in the pull request title (for example: Merge master into c).

- **Description:** The Pull Request description. _(Optional)_.

- **Reviewers:** The Pull Request reviewers _(Optional)_:
  <br> For **Azure DevOps** - one or more email address or team name separated by semicolon. For example: `test@test.com;MyTeamName`.
  <br> For **TFS/Azure DevOps Server** - one or more domain\username or team name separated by semicolon. For example: `DOMAIN\username;DOMAIN\username2`.
  <br> To make the reviewer required in Azure DevOps add 'req:' - e.g. `req:test@test.som`
  <br> For **GitHub** - one or more usernames separated by semicolon. For example: `user1;user2`.

- **Tags:** The Pull Request tags _(Optional)_. tag list separated by semicolon. For example: `tag1;tag2`.

- **Create Draft Pull Request**: If checked the pull request will be a Draft Pull Request. (Default: false) <br> For Azure DevOps: see [here](https://docs.microsoft.com/en-us/azure/devops/repos/git/pull-requests?view=azure-devops#draft-pull-requests) more info. <br> For GitHub: see [here](https://github.blog/2019-02-14-introducing-draft-pull-requests/) more info.

- **Link Work Items**: If checked, all the work items that linked to the commits will be linked also to the PullRequest.

- **Pass Pull Request ID back to Azure DevOps as a variable**: If checked, the Pull Request ID will be passed back to Azure DevOps for use in other pipeline tasks. The variable can be referenced as `$(pullRequestId)`.

- **Always Create Pull Request**: If true, a Pull Request will always be created even if there a no changed files.
 
- **Set Auto Complete**: Only for Azure DevOps. If checked the pull request will close once all branch policies are met.

  Complete options (for Azure DevOps):

  - **Merge Strategy**: Specify the strategy used to merge the pull request during completion, see [here](https://devblogs.microsoft.com/devops/pull-requests-with-rebase/) more info.

    - Merge (No fast-forward) - `noFastForward` in yaml:

      A two-parent, no-fast-forward merge. The source branch is unchanged. **This is the default behavior**.

    - Squash commit - `squash` in yaml:

      Put all changes from the pull request into a single-parent commit.

    - Rebase and fast-forward - `rebase` in yaml:

      Rebase the source branch on top of the target branch HEAD commit, and fast-forward the target branch.
      The source branch is updated during the rebase operation.

    - Rebase and not fast-forward - `rebaseMerge` in yaml:

      Rebase the source branch on top of the target branch HEAD commit, and create a two-parent, no-fast-forward merge.
      The source branch is updated during the rebase operation.

  - **Delete Source Branch**: If true, the source branch of the pull request will be deleted after completion.
  - **Commit Message**: If set, this will be used as the commit message of the merge commit. if empty the default will be used.
  - **Complete Associated Work Items**: If true, we will attempt to transition any work items linked to the pull request into the next logical state (i.e. Active -> Resolved).
  - **Bypass policy**: If true, policies will be explicitly bypassed while the pull request is completed.
    - If you want to use Bypass you need to give also the permisison "Bypass policies when completing pull requests" (check the above **Prerequisites** section).
  - **Bypass reason**: If policies are bypassed, this reason is stored as to why bypass was used.

  Auto Merge options (for GitHub):

  - **Merge Strategy**: Specify the strategy used to merge the pull request during completion, see [here](https://devblogs.microsoft.com/devops/pull-requests-with-rebase/) more info.

    - Merge (No fast-forward) - `merge` in yaml:

      A two-parent, no-fast-forward merge. The source branch is unchanged. **This is the default behavior**.

    - Squash commit - `squash` in yaml:

      Put all changes from the pull request into a single-parent commit.

    - Rebase and fast-forward - `rebase` in yaml:

      Rebase the source branch on top of the target branch HEAD commit, and fast-forward the target branch.
      The source branch is updated during the rebase operation.

  - **Delete Source Branch**: If true, the source branch of the pull request will be deleted after the merge.
  - **Commit Title**: If set, this will be used as the commit title of the merge commit. if empty the default will be used.
  - **Commit Message**: If set, this will be used as the commit message of the merge commit. if empty the default will be used.

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
    # You can select another repository from this project or another project in your account
    # For this, specify `select` in `repositorySelectionMethod` and put the project id & git repo id
    repositorySelectionMethod: select
    projectId: '7fcdaf44-b831-4faa-b2fe-8k7a19a1d1af'
    gitRepositoryId: 'a743g5c4-85ec-4a4e-bf42-78964d551234'
    isForked: false / true (Default: false)
    sourceBranch: '$(Build.SourceBranch)'
    targetBranch: 'master' # Could be also "release/*" or "master;release"
    title: 'Test PR'
    description: 'Test PR' # Optional
    reviewers: For Azure DevOps: 'test@test.com;MyTeam'. For GitHub: `username;username2` # Optional
    # For TFS/Azure DevOps Server: 'DOMAIN\username'
    # To make the reviewer required in Azure DevOps add 'req:' - e.g. 'req:test@test.som'
    tags: 'tag1;tag2'
    isDraft: false / true (Default: false)
    linkWorkItems: false / true (Default: true)
    passPullRequestIdBackToADO: false / true (Default: false)
    alwaysCreatePr: false / true (Default: false)
    # For Azure DevOps
    autoComplete: false / true (Default: false)
    mergeStrategy: 'noFastForward (default) / squash / rebase / rebaseMerge'
    deleteSource:  false / true (Default: false) # Optional
    commitMessage: 'Test Comment' # Optional
    transitionWorkItems:  false / true (Default: false) # Optional
    bypassPolicy: false / true (can't be used with `autoComplete` -the bypass also auto complete the PR) 
    bypassReason: 'Test ByPass' # Optional
    # For GitHub
    githubAutoMerge: false / true (Default: false)
    githubMergeStrategy: 'merge (default) / squash / rebase'
    githubMergeCommitTitle: 'test title' # Optional
    githubMergeCommitMessage: 'test message' # Optional
    githubDeleteSourceBranch: false / true (Default: false) # Optional
  env:
    System_AccessToken: $(System.AccessToken)
```

## Release Notes

| Version | What's new |                                                                                                                                                                                                                                                                                                                                                             
| :------ | :------------------------------------------------------------------------------------------------------------------------- |
| 1.2.318 | Auto merge for GitHub repos  |
| 1.2.296 | Ability to create a PR with tags/labels  |
| 1.2.277 | Add `alwaysCreatePr` option - to create a PR even there are no changes between the branches  |
| 1.2.232 | Can use the token `[BRANCH_NAME]` to dynamically reuse the current target branch name |
| 1.2.226 | Ability to add reviewers also in TFS/Azure DevOps Server |
| 1.2.214 | No need to check the OAuth box! (or add the Access Token variable in the YAML) |
| 1.2.186 | Option to Bypass policy - policies will be explicitly bypassed while the pull request is completed. |
| 1.2.184 | Support also TFS 2018 RTW + Update 1 versions |
| 1.2.180 | Support also Azure DevOps **forks** repsitores (to create PR from the forked repo to the original repo) |
| 1.2.158 | Support also multi-target branch separated with a semicolon, for example: `master;release` |
| 1.2.144 | Support also Azure DevOps groups as reviewers (not also users and teams). |
| 1.2.140 | Return the Pull Request ID as a variable for use in the sequences tasks. |
| 1.2.130 | Now you can add also required reviewers. (for Azure DevOps). |
| 1.2.123 | Ability to choose other repos from your GitHub account. As a result, you can also create GitHub PR from a Release pipeline.|
| 1.2.89  | Throw a warning when there are no commits in the source branch, instead of create a PR (for Azure DevOps). |
| 1.2.76  | Create PR for other repositories - not only for the current build repo (for Azure DevOps) |
| 1.2.48  | Link associated work items to the PR (for Azure DevOps) |
| 1.2.36  | Add complete options like Merge Strategy and more in auto completion (for Azure DevOps). |
| 1.2.30  | Support also a Team as reviewers (for Azure DevOps). |
| 1.2.24  | Set Auto Complete the Pull Request (for Azure DevOps). |
| 1.2.18  | Bug fix: Now you can add reviewers also in TFS 2018 and Azure DevOps Server 2019. |
| 1.2.15  | Draft Pull Request option. |
| 1.2.0   | Support also GitHub repositories! |
| 1.0.31  | Multi target branch (For example: `feature/*`) |
| 1.0.0   | First version. |
