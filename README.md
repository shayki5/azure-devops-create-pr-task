[![Build Status](https://dev.azure.com/shaykia/AzureDevOpsExtensions/_apis/build/status/shayki5.AzureDevOps-CreatePRTask?branchName=master)](https://dev.azure.com/shaykia/AzureDevOpsExtensions/_build/latest?definitionId=34&branchName=master)
[![Release Status](https://vsrm.dev.azure.com/shaykia/_apis/public/Release/badge/3372e1d4-189a-4d9e-aa4d-0cb86eff3c2e/1/2
)](https://vsrm.dev.azure.com/shaykia/_apis/public/Release/badge/3372e1d4-189a-4d9e-aa4d-0cb86eff3c2e/1/2
) 

## Azure DevOps Create Pull Request Task 

Easy way to create a Pull Request from your Build or Release Pipeline. ![Imgur](https://i.imgur.com/5KC8jIk.png)

## Prerequisites before use the task

- **The task works currently only in Windows machines.**

- You need to enable the "Allow scripts to access the OAuth token": 

  - If you use the classic editor, go to the Agent job options, scroll down and check the checkbox "Allow scripts to acess the OAuth token":

    ![Oauth](https://i.imgur.com/ZWuj8Ta.png)

  - If you use `yaml` build, you need to map the variable in the task:

    ```
     env:
       System_AccessToken: $(System.AccessToken)
    ```

## Usage

**In the classic editor:**

![Task](https://i.imgur.com/H2Cu67M.png)

- **Source branch name:** The source branch that will be merged. The default value is the build source branch - `$(Build.SourceBranch)`.

- **Target branch name:** The target branch name that the source branch will be merge to him. For example: `master`.

- **Title:** The Pull Request title.

- **Description:** The Pull Request description. *(Optional)*.

- **Reviewers:** The Pull Request reviewers - one or more email addresses separated by semicolon. For example: `test@test.com;pr@pr.com`. *(Optional)*.

**In yaml piepline:**

```
- task: CreatePullRequest@1
  inputs:
    sourceBranch: '$(Build.SourceBranch)'
    targetBranch: 'master'
    title: 'Test'
    description: 'Test' # Optional
    reviewers: 'test@test.com' # Optional
  env:
     System_AccessToken: $(System.AccessToken)
```

## Release Notes


### New in 1.0.0

 - First version.

