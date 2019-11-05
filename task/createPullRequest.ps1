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
      [bool]$isDraft,
      [bool]$autoComplete
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
       $isDraft = Get-VstsInput -Name 'isDraft' -AsBool
       $autoComplete = Get-VstsInput -Name 'autoComplete' -AsBool
      
       # If the target branch is only one branch
       if(!$targetBranch.Contains('*'))
       {
          CreatePullRequest -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -repoType $repoType -isDraft $isDraft -autoComplete $autoComplete
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
                    CreatePullRequest -sourceBranch $sourceBranch -targetBranch $newTargetBranch -title $title -description $description -reviewers $reviewers -repoType $repoType -isDraft $isDraft -autoComplete $autoComplete
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
       [bool]$isDraft,
       [bool]$autoComplete
    )

    if($repoType -eq "Azure DevOps")
    { 
        CreateAzureDevOpsPullRequest -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -isDraft $isDraft -autoComplete $autoComplete
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
       [bool]$isDraft
    )

    Write-Host "The Source Branch is: $sourceBranch"
    Write-Host "The Target Branch is: $targetBranch"
    Write-Host "The title is: $title"
    Write-Host "The Description is: $description"
    Write-Host "Is Draft Pull Request: $isDraft"

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
        draft = "$isDraft"
    }

    $jsonBody = ConvertTo-Json $body
    Write-Debug $jsonBody
    $header = @{ Authorization=("token $token") ; Accept = "application/vnd.github.shadow-cat-preview+json" }
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
    $header = @{ Authorization=("token $token")}
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
       [bool]$isDraft,
       [bool]$autoComplete
    )

    if(!$sourceBranch.Contains("refs"))
    {
        $sourceBranch = "refs/heads/$sourceBranch"
    }

    $targetBranch = "refs/heads/$targetBranch"  
    Write-Host "The Source Branch is: $sourceBranch"
    Write-Host "The Darget Branch is: $targetBranch"
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
        $usersId = GetReviewerId -reviewers $reviewers
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
            $pullRequestId = $response.pullRequestId
            Write-Host "*************************"
            Write-Host "******** Success ********"
            Write-Host "*************************"
            Write-Host "Pull Request $pullRequestId created."

            # If set auto aomplete is true 
            if($autoComplete)
            {
                SetAutoComplete -pullRequestId $pullRequestId
            }
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

function GetReviewerId()
{
    [CmdletBinding()]
    Param
    (
       [string]$reviewers
    )

    $url = "$($env:System_TeamFoundationCollectionUri)_apis/userentitlements?api-version=4.1-preview.1"
    $url = $url.Replace("//dev","//vsaex.dev")
    Write-Debug $url
    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $users = Invoke-RestMethod -Uri $url -Method Get -ContentType application/json -Headers $head
    $teamsUrl = "$($env:System_TeamFoundationCollectionUri)_apis/projects/$($env:System_TeamProject)/teams?api-version=4.1-preview.1"
    $teams = Invoke-RestMethod -Uri $teamsUrl -Method Get -ContentType application/json -Headers $head
    $reviewers = $reviewers.Split(';')
    $reviewerId = @()
    ForEach($reviewer in $reviewers)
    {
        if ($reviewer.Contains("@"))
        {
            $userId = $users.value.Where({ $_.user.mailAddress -eq $reviewer }).id
            $usersId += @{ id = "$userId" }
        }
        else 
        {
            $teamId = $teams.value.Where({ $_.name -eq $reviewer }).id
            $reviewerId += @{ id = "$teamId" }
        }
    }
    return $reviewerId
}

function SetAutoComplete
{
    [CmdletBinding()]
    Param
    (
       [string]$pullRequestId
    )
    $buildUserId = GetBuildUserId
    $body = @{
        autoCompleteSetBy= @{ id = "$buildUserId" }
    }         

    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $jsonBody = ConvertTo-Json $body
    Write-Debug $jsonBody
    $url = "$env:System_TeamFoundationCollectionUri$env:System_TeamProject/_apis/git/repositories/$env:Build_Repository_Name/pullrequests/$($pullRequestId)?api-version=5.0"
    Write-Debug $url
    try 
    {
        $response =  Invoke-RestMethod -Uri $url -Method Patch -Headers $head -Body $jsonBody -ContentType application/json
        if($Null -ne $response) # If the response not null - the create PR succeeded
        {
            Write-Host "Set Auto Complete to PR $pullRequestId."
        }
    }
    catch 
    {
        Write-Warning "Can't set Auto Complete to PR $pullRequestId."
        Write-Warning $_
        Write-Warning $_.Exception.Message
    }
}

function GetBuildUserId
{
    [CmdletBinding()]

    $url = "$($env:System_TeamFoundationCollectionUri)_apis/graph/users?api-version=4.1-preview.1"
    $url = $url.Replace("//dev","//vssps.dev")
    Write-Debug $url
    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $users = Invoke-RestMethod -Uri $url -Method Get -ContentType application/json -Headers $head
    $buildUserId = $users.value.Where({ $_.displayName -match "Project Collection Build Service" }).originId
    return $buildUserId
}

RunTask