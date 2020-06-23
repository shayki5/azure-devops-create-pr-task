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
        [bool]$linkWorkItems,
        [string]$teamProject,
        [string]$repositoryName,
        [string]$githubRepository,
        [bool]$passPullRequestIdBackToADO
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
        $teamProject = Get-VstsInput -Name 'projectId' 
        $repositoryName = Get-VstsInput -Name 'gitRepositoryId'
        $githubRepository = Get-VstsInput -Name 'githubRepository'
        $passPullRequestIdBackToADO = Get-VstsInput -Name 'passPullRequestIdBackToADO' -AsBool
        
        if ($repositoryName -eq "" -or $repositoryName -eq "currentBuild") {
            $teamProject = $env:System_TeamProject
            $repositoryName = $env:Build_Repository_Name
        }

        #remove spcaes out of Repo Name
        $repositoryName = $repositoryName.Replace(" ", "%20")
      
        # If the target branch is only one branch
        if (!$targetBranch.Contains('*')) {
            CreatePullRequest -teamProject $teamProject -repositoryName $repositoryName -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -repoType $repoType -isDraft $isDraft -autoComplete $autoComplete -mergeStrategy $mergeStrategy -deleteSourch $deleteSourch -commitMessage $commitMessage -transitionWorkItems $transitionWorkItems -linkWorkItems $linkWorkItems -githubRepository $githubRepository -passPullRequestIdBackToADO $passPullRequestIdBackToADO
        }

        # If is multi-target branch, like feature/*
        else {
            if($repoType -eq "Azure DevOps"){
                $url = "$env:System_TeamFoundationCollectionUri$($teamProject)/_apis/git/repositories/$($repositoryName)/refs?api-version=4.1"
                $header = @{ Authorization = "Bearer $env:System_AccessToken" }
                $refs = Invoke-RestMethod -Uri $url -Method Get -Headers $header -ContentType "application/json"
                $targetBranches = ($refs.value.Where({ $_.name -match "$($targetBranch.Replace('*',''))" })).name
                foreach($targetBranch in $targetBranches) {
                    CreatePullRequest -teamProject $teamProject -repositoryName $repositoryName -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -repoType $repoType -isDraft $isDraft -autoComplete $autoComplete -mergeStrategy $mergeStrategy -deleteSourch $deleteSourch -commitMessage $commitMessage -transitionWorkItems $transitionWorkItems -linkWorkItems $linkWorkItems -githubRepository $githubRepository -passPullRequestIdBackToADO $false
                }  
            }
            else {
                $serviceNameInput = Get-VstsInput -Name ConnectedServiceNameSelector -Default 'githubEndpoint'
                $serviceName = Get-VstsInput -Name $serviceNameInput -Default (Get-VstsInput -Name DeploymentEnvironmentName)
                if (!$serviceName) {
                    # Let the task SDK throw an error message if the input isn't defined.
                    Get-VstsInput -Name $serviceNameInput -Require
                }
                $endpoint = Get-VstsEndpoint -Name $serviceName -Require
                $token = $endpoint.Auth.Parameters.accessToken
                $repoUrlSplitted = $githubRepository.Split('/')
                $owner = $repoUrlSplitted.Split('/')[0]
                $repo = $repoUrlSplitted.Split('/')[1]
                $url = "https://api.github.com/repos/$owner/$repo/branches"
                $header = @{ Authorization = ("token $token") ; Accept = "application/vnd.github.shadow-cat-preview+json" }
                $branches = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json" -Headers $header
                $targetBranches = $branches.name.Where({ $_ -match "$($targetBranch.Replace('*',''))" })
                foreach($targetBranch in $targetBranches) {
                    CreatePullRequest -teamProject $teamProject -repositoryName $repositoryName -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -repoType $repoType -isDraft $isDraft -autoComplete $autoComplete -mergeStrategy $mergeStrategy -deleteSourch $deleteSourch -commitMessage $commitMessage -transitionWorkItems $transitionWorkItems -linkWorkItems $linkWorkItems -githubRepository $githubRepository -passPullRequestIdBackToADO $false
                }  
            }
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
        [bool]$linkWorkItems,
        [string]$teamProject,
        [string]$repositoryName,
        [string]$githubRepository,
        [bool]$passPullRequestIdBackToADO
    )

    if ($repoType -eq "Azure DevOps") { 
        CreateAzureDevOpsPullRequest -teamProject $teamProject -repositoryName $repositoryName -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -isDraft $isDraft -autoComplete $autoComplete -mergeStrategy $mergeStrategy -deleteSourch $deleteSourch -commitMessage $commitMessage -transitionWorkItems $transitionWorkItems -linkWorkItems $linkWorkItems -passPullRequestIdBackToADO $passPullRequestIdBackToADO
    }

    else {
        # Is GitHub repository
        CreateGitHubPullRequest -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers -isDraft $isDraft -githubRepository $githubRepository -passPullRequestIdBackToADO $passPullRequestIdBackToADO
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
        [bool]$isDraft,
        [string]$githubRepository,
        [bool]$passPullRequestIdBackToADO
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
    $repoUrlSplitted = $githubRepository.Split('/')
    $owner = $repoUrlSplitted.Split('/')[0]
    $repo = $repoUrlSplitted.Split('/')[1]
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
        $response = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json;charset=UTF-8" -Headers $header -Body $jsonBody
        if ($Null -ne $response) {
            # If the response not null - the create PR succeeded
            Write-Host "*************************"
            Write-Host "******** Success ********"
            Write-Host "*************************"
            Write-Host "Pull Request $($response.number) created."

            if ($passPullRequestIdBackToADO) {
                # Pass pullRequestId back to Azure DevOps for consumption by other pipeline tasks
                write-host "##vso[task.setvariable variable=pullRequestId]$($response.number)"
            }

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
        [bool]$linkWorkItems,
        [string]$teamProject,
        [string]$repositoryName,
        [bool]$passPullRequestIdBackToADO
    )

    if (!$sourceBranch.Contains("refs")) {
        $sourceBranch = "refs/heads/$sourceBranch"
    }
    
    if (!$targetBranch.Contains("refs")) {
        $targetBranch = "refs/heads/$targetBranch"
    }

    Write-Host "The Source Branch is: $sourceBranch"
    Write-Host "The Target Branch is: $targetBranch"
    Write-Host "The Title is: $title"
    Write-Host "The Description is: $description"
    Write-Host "Is Reviewers are: $reviewers"
    Write-Host "Is Draft Pull Request: $isDraft"

    CheckIfThereAreChanges -sourceBranch $sourceBranch -targetBranch $targetBranch

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
        $workItems = GetLinkedWorkItems -teamProject $teamProject -repositoryName $repositoryName -sourceBranch $sourceBranch.Remove(0, 11) -targetBranch $targetBranch.Remove(0, 11)
        $body.WorkItemRefs = @( $workItems )
    }

    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $jsonBody = ConvertTo-Json $body
    Write-Host $jsonBody
    $url = "$env:System_TeamFoundationCollectionUri$($teamProject)/_apis/git/repositories/$($repositoryName)/pullrequests?api-version=5.0"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $head -Body $jsonBody -ContentType "application/json;charset=UTF-8"
        if ($Null -ne $response) {
            # If the response not null - the create PR succeeded
            $pullRequestId = $response.pullRequestId
            Write-Host "*************************"
            Write-Host "******** Success ********"
            Write-Host "*************************"
            Write-Host "Pull Request $pullRequestId created."
            
            if ($passPullRequestIdBackToADO) {
                # Pass pullRequestId back to Azure DevOps for consumption by other pipeline tasks
                write-host "##vso[task.setvariable variable=pullRequestId]$pullRequestId"
            }

            $currentUserId = $response.createdBy.id

            # If set auto aomplete is true 
            if ($autoComplete) {
                SetAutoComplete -teamProject $teamProject -repositoryName $repositoryName -pullRequestId $pullRequestId -buildUserId $currentUserId -mergeStrategy $mergeStrategy -deleteSourch $deleteSourch -commitMessage $commitMessage -transitionWorkItems $transitionWorkItems
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

function CheckIfThereAreChanges {
    Param (
        [string]$sourceBranch,
        [string]$targetBranch
    )

    # Remove the refs/heads/ from the branchs name
    $sourceBranch = $sourceBranch.Remove(0, 11)
    if($sourceBranch -match "#"){
         $sourceBranch = $sourceBranch.Replace('#','%23') 
    }
    $targetBranch = $targetBranch.Remove(0, 11)
    if($targetBranch -match "#"){
         $targetBranch = $targetBranch.Replace('#','%23') 
    }
    $url = "$env:System_TeamFoundationCollectionUri$($teamProject)/_apis/git/repositories/$($repositoryName)/diffs/commits?baseVersion=$($sourceBranch)&targetVersion=$($targetBranch)&api-version=4.1" + '&$top=2'
    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $head -ContentType "application/json"
    if ($response.behindCount -eq 0) {
        Write-Warning "***************************************************************"
        Write-Warning "There are no new commits in the source branch, no PR is needed!"
        Write-Warning "***************************************************************"
        exit 0
    }
    else {
        Write-Host "$($response.behindCount) new commits! perofrm a Pull Request..."
    }

    
}

function GetReviewerId() {
    [CmdletBinding()]
    Param
    (
        [string]$reviewers
    )

    $serverUrl = $env:System_TeamFoundationCollectionUri
    $head = @{ Authorization = "Bearer $env:System_AccessToken" }

    # If it's TFS/AzureDevOps Server
    if ($serverUrl -notmatch "visualstudio.com" -and $serverUrl -notmatch "dev.azure.com") {

        $url = "$($env:System_TeamFoundationCollectionUri)_apis/projects/$($env:System_TeamProject)/teams?api-version=4.1"

        $teams = Invoke-RestMethod -Method Get -Uri $url -Headers $head -ContentType 'application/json'
        Write-Debug $reviewers
        $split = $reviewers.Split(';')
        $reviewersId = @()
        ForEach ($reviewer in $split) {
            $isRequired = "false"
            if ($reviewer -match "req:") {
                $reviewer = $reviewer.Replace("req:","")
                $isRequired = "true"
            }
            # If the reviewer is user
            if ($reviewer.Contains("@")) {

                $teams.value.ForEach( {
                        $teamUrl = "$($env:System_TeamFoundationCollectionUri)_apis/projects/$($env:System_TeamProject)/teams/$($_.id)/members?api-version=4.1"
                        $team = Invoke-RestMethod -Method Get -Uri $teamUrl -Headers $head -ContentType 'application/json'
        
                        # If the team contains only 1 user
                        if ($team.count -eq 1) {
                            if ($team.value.identity.uniqueName -eq $reviewer) {
                                $userId = $team.value.identity.id
                                Write-Host $userId -ForegroundColor Green
                                $reviewersId += @{ 
                                    id = "$userId"
                                    isRequired = "$isRequired"
                                }
                                break
                            }
                        }
                        else {
                            # If the team contains more than 1 user 
                            $userId = $team.value.identity.Where( { $_.uniqueName -eq $reviewer }).id
                            if ($null -ne $userId) {
                                Write-Host $userId -ForegroundColor Green
                                $reviewersId += @{ 
                                    id = "$userId"
                                    isRequired = "$isRequired"
                                }
                                break
                            }
                        }
                    })
            }       

            # If the reviewer is team
            else {
                if ($teams.count -eq 1) {
                    if ($teams.value.name -eq $u) {
                        $teamId = $teams.value.id
                        Write-Host $teamId -ForegroundColor Green
                        $reviewersId += @{ 
                            id = "$teamId"
                            isRequired = "$isRequired"
                        }
                    }
                }
                else {
                    $teamId = $teams.value.Where( { $_.name -eq $u }).id
                    Write-Host $teamId -ForegroundColor Green
                    $reviewersId += @{ 
                        id = "$teamId"
                        isRequired = "$isRequired"
                    }
                }
            }
        }
    }
    
    # If it's Azure DevOps
    else {
        $url = "$($env:System_TeamFoundationCollectionUri)_apis/userentitlements?top=5000&api-version=4.1-preview.1"
        # Check if it's the old url or the new url, reltaed to issue #21
        # And add "vsaex" to the rest api url 
        if ($url -match "visualstudio.com") {
            $url = $url.Replace(".visualstudio", ".vsaex.visualstudio")
        }
        else {
            $url = $url.Replace("//dev", "//vsaex.dev")
        }
        $users = Invoke-RestMethod -Uri $url -Method Get -ContentType application/json -Headers $head
        $teamsUrl = "$($env:System_TeamFoundationCollectionUri)_apis/projects/$($env:System_TeamProject)/teams?api-version=4.1-preview.1"
        $teams = Invoke-RestMethod -Uri $teamsUrl -Method Get -ContentType application/json -Headers $head
        Write-Debug $reviewers
        $split = $reviewers.Split(';')
        $reviewersId = @()
        ForEach ($reviewer in $split) {
            $isRequired = "false"
            if ($reviewer -match "req:") {
                $reviewer = $reviewer.Replace("req:","")
                $isRequired = "true"
            }
            if ($reviewer.Contains("@")) {
                # Is user
                $userId = $users.value.Where( { $_.user.mailAddress -eq $reviewer }).id
                $reviewersId += @{ 
                    id = "$userId"
                    isRequired = "$isRequired"
                }
            }
            else {
                # Is team
                $teamId = $teams.value.Where( { $_.name -eq $reviewer }).id
                Write-Debug "$teamId"
                # If the teamId is null so maybe it's a TFS group
                # If it's Azure DevOps (not TFS) we can get the group ID 
                if($Null -eq $teamId) {
                    Write-Debug "Not found team id, check if it's a group"
                    $base_url = $env:System_TeamFoundationCollectionUri	
                    if ($base_url -match "https://(.*)\.visualstudio\.com/$") {	
                        $url = "https://vssps.dev.azure.com/$($Matches[1])/"	
                    }	
                    else {	
                        $url = $base_url.Replace("//dev", "//vssps.dev")	
                    }	
                    $url = "$($url)_apis/graph/groups?api-version=4.1-preview.1"	
                    $head = @{ Authorization = "Bearer $env:System_AccessToken" }	
                    $response = Invoke-WebRequest -Uri $url -Method Get -ContentType application/json -Headers $head -UseBasicParsing
                    # If the results are more then 500 users and the Project Collection Build Service not exist in the first page	
                    while ($response.Headers.Keys -contains "x-ms-continuationtoken" -and $response.Content -notmatch "$reviewer") {	
                        $token = $response.Headers.'x-ms-continuationtoken'	
                        $url_with_token = "$($url)&continuationToken=$($token)"	
                        $response = Invoke-WebRequest -Uri $url_with_token -Method Get -ContentType application/json -Headers $head	-UseBasicParsing
                    }	
                    $teamId = ($response.Content | Convertfrom-Json).value.Where( { $_ -match "$reviewer" }).originId	
                }   
                $reviewersId += @{ 
                    id = "$teamId"
                    isRequired = "$isRequired"
                }
            }
        }
    }
    return $reviewersId
}

function GetLinkedWorkItems {
    [CmdletBinding()]
    Param
    (
        [string]$sourceBranch,
        [string]$targetBranch,
        [string]$teamProject,
        [string]$repositoryName
    )
    $url = "$env:System_TeamFoundationCollectionUri$($teamProject)/_apis/git/repositories/$($repositoryName)/commitsBatch?api-version=4.1"
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
        [bool]$transitionWorkItems,
        [string]$teamProject,
        [string]$repositoryName,
        [string]$buildUserId
    )

    $body = @{
        autoCompleteSetBy = @{ id = "$buildUserId" }
        completionOptions = ""
    }    

    $options = @{ 
        mergeStrategy       = "$mergeStrategy" 
        deleteSourceBranch  = "$deleteSourch"
        transitionWorkItems = "$transitionWorkItems"
        mergeCommitMessage  = "$commitMessage"
    }
    $body.completionOptions = $options

    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $jsonBody = ConvertTo-Json $body
    Write-Debug $jsonBody
    $url = "$env:System_TeamFoundationCollectionUri$($teamProject)/_apis/git/repositories/$($repositoryName)/pullrequests/$($pullRequestId)?api-version=5.0"
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

RunTask
