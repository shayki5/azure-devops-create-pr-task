function RunTask
{
   [CmdletBinding()]
   Param
   (
      [string]$sourceBranch,
      [string]$targetBranch,
      [string]$title,
      [string]$description,
      [string]$reviewers,
      [string]$isDraft
   )

   Trace-VstsEnteringInvocation $MyInvocation
   try
   {
       # Get inputs
       $sourceBranch = Get-VstsInput -Name 'sourceBranch' -Require
       $targetBranch = Get-VstsInput -Name 'targetBranch' -Require
       $title = Get-VstsInput -Name 'title' -Require
       $description = Get-VstsInput -Name 'description'
       $reviewers = Get-VstsInput -Name 'reviewers'
       $repoType = Get-VstsInput -Name 'repoType' -Require
       $isDraft = Get-VstsInput -Name 'isDraft'
      
       # If the target branch is only one branch
       if(!$targetBranch.Contains('*'))
       {
          CreatePullRequest -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -repoType $repoType -isDraft $isDraft
       }

       # If is multi-target branch, like feature/*
       else
       {
           Set-Location $env:Build_SourcesDirectory
           $branches = git branch -a
           $branches.ForEach({
                if($_ -match ($targetBranch.Split('/')[0]))
                {
                    $newTargetBranch = $_.Split('/')[2] + "/" + $_.Split('/')[3]
                    $newTargetBranch = "$newTargetBranch"
                    CreatePullRequest -sourceBranch $sourceBranch -targetBranch $newTargetBranch -title $title -description $description -reviewers $reviewers -repoType $repoType -isDraft $isDraft
                }
           })
       }
   }

   finally
   {
       Trace-VstsLeavingInvocation $MyInvocation
   }
}

function CreatePullRequest()
{
    [CmdletBinding()]
    Param
    (
       [string]$repoType,
       [string]$sourceBranch,
       [string]$targetBranch,
       [string]$title,
       [string]$description,
       [string]$reviewers,
       [string]$isDraft
    )

    if($repoType -eq "Azure DevOps")
    { 
        CreateAzureDevOpsPullRequest -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -isDraft $isDraft
    }

    else # Is GitHub repository
    {
        CreateGitHubPullRequest -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -isDraft $isDraft
    }
}

function CreateGitHubPullRequest()
{
    [CmdletBinding()]
    Param
    (
       [string]$repoType,
       [string]$sourceBranch,
       [string]$targetBranch,
       [string]$title,
       [string]$description,
       [string]$reviewers,
       [string]$isDraft
    )

    Write-Host "The source branch is: $sourceBranch"
    Write-Host "The target branch is: $targetBranch"
    Write-Host "The title is: $title"
    Write-Host "The description is: $description"
    $serviceNameInput = Get-VstsInput -Name ConnectedServiceNameSelector -Default 'githubEndpoint'
    $serviceName = Get-VstsInput -Name $serviceNameInput -Default (Get-VstsInput -Name DeploymentEnvironmentName)
    if (!$serviceName) {
        # Let the task SDK throw an error message if the input isn't defined.
        Get-VstsInput -Name $serviceNameInput -Require
    }

    $endpoint = Get-VstsEndpoint -Name $serviceName -Require
    $token = $endpoint.Auth.Parameters.accessToken
    $repoUrl = $env:BUILD_REPOSITORY_URI
    $owner = $repoUrl.Split('/')[3]
    $repo = $repoUrl.Split('/')[4]
    $url = "https://api.github.com/repos/$owner/$repo/pulls"
    $body = @{
        head = "$sourceBranch"
        base = "$targetBranch"
        title = "$title"
        body = "$description"
    }

    $jsonBody = ConvertTo-Json $body
    Write-Debug $jsonBody
    $header = @{Authorization=("token $token")}
    try
    {
        $response =  Invoke-RestMethod -Uri $url -Method Post -ContentType application/json -Headers $header -Body $jsonBody
        if($response -ne $Null) # If the response not null - the create PR succeeded
        {
            Write-Host "*************************"
            Write-Host "******** Success ********"
            Write-Host "*************************"
            Write-Host "Pull Request $($response.number) created."
            # If the reviewers not null so add the reviewers to the PR
            if($reviewers -ne "")
            {
                CreateGitHubReviewers -reviewers $reviewers -token $token -prNumber $response.number
            }
        }
    }

    catch
    {
        Write-Error $_
        Write-Error $_.Exception.Message
    }
}

function CreateGitHubReviewers()
{
    [CmdletBinding()]
    Param
    (
       [string]$reviewers,
       [string]$token,
       [string]$prNumber
    )
    $reviewers = $reviewers.Split(';')
    $repoUrl = $env:BUILD_REPOSITORY_URI
    $owner = $repoUrl.Split('/')[3]
    $repo = $repoUrl.Split('/')[4]
    $url = "https://api.github.com/repos/$owner/$repo/pulls/$prNumber/requested_reviewers"
    $body = @{
        reviewers = @()
    }
    ForEach($reviewer in $reviewers)
    {
        $body.reviewers += $reviewer
    }
    $jsonBody = $body | ConvertTo-Json
    Write-Debug $jsonBody
    $header = @{Authorization=("token $token")}
    try
    {
        Write-Host "Add reviewers the the Pull Request..."
        $response =  Invoke-RestMethod -Uri $url -Method Post -ContentType application/json -Headers $header -Body $jsonBody
        if($response -ne $Null) # If the response not null - the create PR succeeded
        {
            Write-Host "******** Success ********"
            Write-Host "Reviewrs are addedd to PR #$prNumber"
        }
    }

    catch
    {
        Write-Error $_
        Write-Error $_.Exception.Message
    }
}

function CreateAzureDevOpsPullRequest()
{
    [CmdletBinding()]
    Param
    (
       [string]$sourceBranch,
       [string]$targetBranch,
       [string]$title,
       [string]$description,
       [string]$reviewers,
       [string]$isDraft
    )
    if(!$sourceBranch.Contains("refs"))
    {
        $sourceBranch = "refs/heads/$sourceBranch"
    }

    $targetBranch = "refs/heads/$targetBranch"  
    Write-Host "The Source Branch is: $sourceRefName"
    Write-Host "The Darget Branch is: $targetRefName"
    Write-Host "The Title is: $title"
    Write-Host "The Description is: $description"
    Write-Host "Is Draft Pull Request: $isDraft"

    $body = @{
        sourceRefName = "$sourceBranch"
        targetRefName = "$targetBranch"
        title = "$title"
        description = "$description"
        reviewers = ""
        isDraft = "$isDraft"
    }

    if($reviewers -ne "")
    {
        $usersId = GetUsersId -reviewers $reviewers
        $body.reviewers = @( $usersId )
        Write-Host "The reviewers are: $($reviewers.Split(';'))"
    }

    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $jsonBody = ConvertTo-Json $body
    Write-Debug $jsonBody
    $url = "$env:System_TeamFoundationCollectionUri$env:System_TeamProject/_apis/git/repositories/$env:Build_Repository_Name/pullrequests?api-version=5.0"
    Write-Debug $url

    try
    {
        $response =  Invoke-RestMethod -Uri $url -Method Post -Headers $head -Body $jsonBody -ContentType application/json
        if($response -ne $Null) # If the response not null - the create PR succeeded
        {
            Write-Host "*************************"
            Write-Host "******** Success ********"
            Write-Host "*************************"
            Write-Host "Pull Request $($response.pullRequestId) created."
        }
    }

    catch
    {
        # If the error contains TF401179 it's mean that there is alredy a PR for the branches, so I display a warning
        if($_ -match "TF401179")
        {
            Write-Warning $_
        }

        else # If there is an error - fail the task
        {
            Write-Error $_
            Write-Error $_.Exception.Message
        }
    }
}

function GetUsersId()

{
    [CmdletBinding()]
    Param
    (
       [string]$reviewers
    )

    $url = "$($env:System_TeamFoundationCollectionUri)_apis/userentitlements?api-version=5.0-preview.2"
    $url = $url.Replace("//dev","//vsaex.dev")
    Write-Debug $url
    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $users = Invoke-RestMethod -Uri $url -Method Get -ContentType application/json -Headers $head
    $reviewers = $reviewers.Split(';')
    $usersId = @()
    ForEach($reviewer in $reviewers)
    {
        $userId = $users.items.Where({ $_.user.mailAddress -eq $reviewer }).id
        $usersId += @{ id = "$userId" }

    }
    return $usersId
}

RunTask