function RunTask {
    [CmdletBinding()]
    Param
    (
        [string]$sourceBranch,
        [string]$targetBranch,
        [string]$title,
        [string]$description,
        [string]$reviewers,
        [bool]$isDraft,
        [bool]$autoComplete,
        [string]$mergeStrategy,
        [bool]$deleteSourch,
        [string]$commitMessage,
        [bool]$transitionWorkItems,
        [bool]$linkWorkItems
    )

    Trace-VstsEnteringInvocation $MyInvocation
    try {
        # Get inputs
        $sourceBranch = Get-VstsInput -Name 'sourceBranch' -Require
        $targetBranch = Get-VstsInput -Name 'targetBranch' -Require
        $title = Get-VstsInput -Name 'title' -Require
        $description = Get-VstsInput -Name 'description'
        $reviewers = Get-VstsInput -Name 'reviewers'
        $repoType = Get-VstsInput -Name 'repoType' -Require
        $isDraft = Get-VstsInput -Name 'isDraft' -AsBool
        $autoComplete = Get-VstsInput -Name 'autoComplete' -AsBool
        $mergeStrategy = Get-VstsInput -Name 'mergeStrategy' 
        $deleteSourch = Get-VstsInput -Name 'deleteSourch' -AsBool
        $commitMessage = Get-VstsInput -Name 'commitMessage' 
        $transitionWorkItems = Get-VstsInput -Name 'transitionWorkItems' -AsBool
        $linkWorkItems = Get-VstsInput -Name 'linkWorkItems' -AsBool
      
        # If the target branch is only one branch
        if (!$targetBranch.Contains('*')) {
            CreatePullRequest -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -repoType $repoType -isDraft $isDraft -autoComplete $autoComplete -mergeStrategy $mergeStrategy -deleteSourch $deleteSourch -commitMessage $commitMessage -transitionWorkItems $transitionWorkItems -linkWorkItems $linkWorkItems
        }

        # If is multi-target branch, like feature/*
        else {
            Set-Location $env:Build_SourcesDirectory
            $branches = git branch -a
            $branches.ForEach( {
                    if ($_ -match ($targetBranch.Split('/')[0])) {
                        $newTargetBranch = $_.Remove(0, 17)
                        $newTargetBranch = "$newTargetBranch"
                        CreatePullRequest -sourceBranch $sourceBranch -targetBranch $newTargetBranch -title $title -description $description -reviewers $reviewers -repoType $repoType -isDraft $isDraft -autoComplete $autoComplete -mergeStrategy $mergeStrategy -deleteSourch $deleteSourch -commitMessage $commitMessage -transitionWorkItems $transitionWorkItems -linkWorkItems $linkWorkItems
                    }
                })
        }
    }

    finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

function CreatePullRequest() {
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
        [bool]$autoComplete,
        [string]$mergeStrategy,
        [bool]$deleteSourch,
        [string]$commitMessage,
        [bool]$transitionWorkItems,
        [bool]$linkWorkItems
    )

    if ($repoType -eq "Azure DevOps") { 
        CreateAzureDevOpsPullRequest -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -isDraft $isDraft -autoComplete $autoComplete -mergeStrategy $mergeStrategy -deleteSourch $deleteSourch -commitMessage $commitMessage -transitionWorkItems $transitionWorkItems -linkWorkItems $linkWorkItems
    }

    else {
        # Is GitHub repository
        CreateGitHubPullRequest -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -isDraft $isDraft
    }
}

function CreateGitHubPullRequest() {
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
    Write-Host "The Title is: $title"
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
        head  = "$sourceBranch"
        base  = "$targetBranch"
        title = "$title"
        body  = "$description"
    }

    # Add the draft property only if is true and not add draft=false when it's false because there are github repos that doesn't support draft PR. see github issue #13
    if ($isDraft -eq $True) {
        $body.Add("draft" , $isDraft)
    }

    $jsonBody = ConvertTo-Json $body
    Write-Debug $jsonBody
    $header = @{ Authorization = ("token $token") ; Accept = "application/vnd.github.shadow-cat-preview+json" }
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -ContentType application/json -Headers $header -Body $jsonBody
        if ($Null -ne $response) {
            # If the response not null - the create PR succeeded
            Write-Host "*************************"
            Write-Host "******** Success ********"
            Write-Host "*************************"
            Write-Host "Pull Request $($response.number) created."
            # If the reviewers not null so add the reviewers to the PR
            if ($reviewers -ne "") {
                CreateGitHubReviewers -reviewers $reviewers -token $token -prNumber $response.number
            }
        }
    }

    catch {
        Write-Error $_
        Write-Error $_.Exception.Message
    }
}

function CreateGitHubReviewers() {
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
    ForEach ($reviewer in $reviewers) {
        $body.reviewers += $reviewer
    }
    $jsonBody = $body | ConvertTo-Json
    Write-Debug $jsonBody
    $header = @{ Authorization = ("token $token") }
    try {
        Write-Host "Add reviewers to the Pull Request..."
        $response = Invoke-RestMethod -Uri $url -Method Post -ContentType application/json -Headers $header -Body $jsonBody
        if ($Null -ne $response) {
            # If the response not null - the create PR succeeded
            Write-Host "******** Success ********"
            Write-Host "Reviewers were added to PR #$prNumber"
        }
    }

    catch {
        Write-Error $_
        Write-Error $_.Exception.Message
    }
}

function CreateAzureDevOpsPullRequest() {
    [CmdletBinding()]
    Param
    (
        [string]$sourceBranch,
        [string]$targetBranch,
        [string]$title,
        [string]$description,
        [string]$reviewers,
        [bool]$isDraft,
        [bool]$autoComplete,
        [string]$mergeStrategy,
        [bool]$deleteSourch,
        [string]$commitMessage,
        [bool]$transitionWorkItems,
        [bool]$linkWorkItems
    )

    if (!$sourceBranch.Contains("refs")) {
        $sourceBranch = "refs/heads/$sourceBranch"
    }

    $targetBranch = "refs/heads/$targetBranch"  
    Write-Host "The Source Branch is: $sourceBranch"
    Write-Host "The Target Branch is: $targetBranch"
    Write-Host "The Title is: $title"
    Write-Host "The Description is: $description"
    Write-Host "Is Draft Pull Request: $isDraft"

    $body = @{
        sourceRefName = "$sourceBranch"
        targetRefName = "$targetBranch"
        title         = "$title"
        description   = "$description"
        reviewers     = ""
        isDraft       = "$isDraft"
        WorkItemRefs  = ""
    }

    if ($reviewers -ne "") {
        $usersId = GetReviewerId -reviewers $reviewers
        $body.reviewers = @( $usersId )
        Write-Host "The reviewers are: $($reviewers.Split(';'))"
    }

    if ($linkWorkItems -eq $True) {
        $workItems = GetLinkedWorkItems -sourceBranch $sourceBranch.Remove(0, 11) -targetBranch $targetBranch.Remove(0, 11)
        $body.WorkItemRefs = @( $workItems )
    }

    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $jsonBody = ConvertTo-Json $body
    Write-Debug $jsonBody
    $url = "$env:System_TeamFoundationCollectionUri$env:System_TeamProject/_apis/git/repositories/$env:Build_Repository_Name/pullrequests?api-version=5.0"
    Write-Debug $url

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $head -Body $jsonBody -ContentType application/json
        if ($Null -ne $response) {
            # If the response not null - the create PR succeeded
            $pullRequestId = $response.pullRequestId
            Write-Host "*************************"
            Write-Host "******** Success ********"
            Write-Host "*************************"
            Write-Host "Pull Request $pullRequestId created."

            # If set auto aomplete is true 
            if ($autoComplete) {
                SetAutoComplete -pullRequestId $pullRequestId -mergeStrategy $mergeStrategy -deleteSourch $deleteSourch -commitMessage $commitMessage -transitionWorkItems $transitionWorkItems
            }
        }
    }

    catch {
        # If the error contains TF401179 it's mean that there is alredy a PR for the branches, so I display a warning
        if ($_ -match "TF401179") {
            Write-Warning $_
        }

        else {
            # If there is an error - fail the task
            Write-Error $_
            Write-Error $_.Exception.Message
        }
    }
}

function GetReviewerId() {
    [CmdletBinding()]
    Param
    (
        [string]$reviewers
    )

    $url = "$($env:System_TeamFoundationCollectionUri)_apis/userentitlements?api-version=4.1-preview.1"
    # Check if it's the old url or the new url, reltaed to issue #21
    # And add "vsaex" to the rest api url 
    if ($url -match "visualstudio.com") {
        $url = $url.Replace(".visualstudio", ".vsaex.visualstudio")
    }
    else {
        $url = $url.Replace("//dev", "//vsaex.dev")
    }
    Write-Debug $url
    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $users = Invoke-RestMethod -Uri $url -Method Get -ContentType application/json -Headers $head
    $teamsUrl = "$($env:System_TeamFoundationCollectionUri)_apis/projects/$($env:System_TeamProject)/teams?api-version=4.1-preview.1"
    $teams = Invoke-RestMethod -Uri $teamsUrl -Method Get -ContentType application/json -Headers $head
    Write-Debug $reviewers
    $split = $reviewers.Split(';')
    $reviewersId = @()
    ForEach ($reviewer in $split) {
        if ($reviewer.Contains("@")) {
            # Is user
            $userId = $users.value.Where( { $_.user.mailAddress -eq $reviewer }).id
            $reviewersId += @{ id = "$userId" }
        }
        else {
            # Is team
            $teamId = $teams.value.Where( { $_.name -eq $reviewer }).id
            $reviewersId += @{ id = "$teamId" }
        }
    }
    Write-Host "final reviewersId: $reviewersId"
    return $reviewersId
}

function GetLinkedWorkItems {
    [CmdletBinding()]
    Param
    (
        [string]$sourceBranch,
        [string]$targetBranch
    )
    $url = "$env:System_TeamFoundationCollectionUri$env:System_TeamProject/_apis/git/repositories/$env:Build_Repository_Name/commitsBatch?api-version=4.1"
    $header = @{ Authorization = "Bearer $env:System_AccessToken" }
    $body = @{
        '$top'           = 101
        includeWorkItems = "true"
        itemVersion      = @{
            versionOptions = 0
            versionType    = 0
            version        = "$targetBranch"
        }
        compareVersion   = @{
            versionOptions = 0
            versionType    = 0
            version        = "$sourceBranch"
        }
    }
    $jsonBody = $body | ConvertTo-Json
    Write-Debug $jsonBody
    $response = Invoke-RestMethod -Method Post -Uri $url -Headers $header -Body $jsonBody -ContentType 'application/json'
    Write-Debug $response
    $commits = $response.value
    $workItemsId = @()
    $commits.ForEach( { 
            if ($_.workItems.length -gt 0) {
                $_.workItems.ForEach( {
                        # Check if it's the old url or the new url, reltaed to issue #18
                        if ($_.url -match "visualstudio.com") {
                            $workItemsId += $_.url.split('/')[6]

                        }
                        else {
                            $workItemsId += $_.url.split('/')[7]
                        }
                    }
                )
            }
        })
    if ($workItemsId.Count -gt 0) {
        $workItems = @()
        ($workItemsId | Select-Object -Unique).ForEach( {
                $workItem = @{
                    id  = $_
                    url = ""
                }
                $workItems += $workItem
            })      
    }
    return $workItems
}

function SetAutoComplete {
    [CmdletBinding()]
    Param
    (
        [string]$pullRequestId,
        [string]$mergeStrategy,
        [bool]$deleteSourch,
        [string]$commitMessage,
        [bool]$transitionWorkItems
    )
    $buildUserId = GetBuildUserId
    $body = @{
        autoCompleteSetBy = @{ id = "$buildUserId" }
        completionOptions = ""
    }         
    $options = @{ 
        mergeStrategy       = "$mergeStrategy" 
        deleteSourceBranch  = "$deleteSourch"
        transitionWorkItems = "$transitionWorkItems"
        commitMessage       = "$commitMessage"
    }
    $body.completionOptions = $options

    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $jsonBody = ConvertTo-Json $body
    Write-Debug $jsonBody
    $url = "$env:System_TeamFoundationCollectionUri$env:System_TeamProject/_apis/git/repositories/$env:Build_Repository_Name/pullrequests/$($pullRequestId)?api-version=5.0"
    Write-Debug $url
    try {
        $response = Invoke-RestMethod -Uri $url -Method Patch -Headers $head -Body $jsonBody -ContentType application/json
        if ($Null -ne $response) {
            # If the response not null - the create PR succeeded
            Write-Host "Set Auto Complete to PR $pullRequestId."
        }
    }
    catch {
        Write-Warning "Can't set Auto Complete to PR $pullRequestId."
        Write-Warning $_
        Write-Warning $_.Exception.Message
    }
}

function GetBuildUserId {
    [CmdletBinding()]
    $url = "$($env:System_TeamFoundationCollectionUri)_apis/graph/users?api-version=4.1-preview.1"
    $url = $url.Replace("//dev", "//vssps.dev")
    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $response = Invoke-WebRequest -Uri $url -Method Get -ContentType application/json -Headers $head
    # If the results are more then 500 users and the Project Collection Build Service not exist in the first page
    while ($response.Headers.Keys -contains "x-ms-continuationtoken" -and $response.Content -notmatch "Project Collection Build Service") {
        $token = $response.Headers.'x-ms-continuationtoken'
        $url = "$($env:System_TeamFoundationCollectionUri)_apis/graph/users?continuationToken=$($token)&api-version=4.1-preview.1"
        $url = $url.Replace("//dev", "//vssps.dev")
        $response = Invoke-WebRequest -Uri $url -Method Get -ContentType application/json -Headers $head
    }
    $buildUserId = ($response.Content | Convertfrom-Json).value.Where( { $_.displayName -match "Project Collection Build Service" }).originId
    return $buildUserId
}

RunTask