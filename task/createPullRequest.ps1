function RunTask
{
   [CmdletBinding()]
   param(
      [string] $sourceBranch,
      [string] $targetBranch,
      [string] $title,
      [string] $description,
      [string] $reviewers
   )

   Trace-VstsEnteringInvocation $MyInvocation
   try {
       # Get inputs
       $sourceBranch = Get-VstsInput -Name 'sourceBranch' -Require
       $targetBranch = Get-VstsInput -Name 'targetBranch' -Require
       $title = Get-VstsInput -Name 'title' -Require
       $description = Get-VstsInput -Name 'description'
       $reviewers = Get-VstsInput -Name 'reviewers'
       if(!$sourceBranch.Contains("refs"))
       {
           $sourceBranch = "refs/heads/$sourceBranch"
       }

       # If the tagert branch is only one branch
       if(!$targetBranch.Contains('*'))
       {
           $targetBranch = "refs/heads/$targetBranch"     
           CheckReviewersAndCreatePR -sourceBranch $sourceBranch -targetBranch $targetBranch -title $title -description $description -reviewers $reviewers
        }

       # If the target branch is like feature/*
       else
       {
           Set-Location $env:Build_SourcesDirectory
           $branches = git branch -a
           $branches.ForEach({
           if($_.Contains($targetBranch.Split('/')[0]))
            {
                $newTargetBranch = $_.Split('/')[2]
                $newTargetBranch = "refs/heads/$newTargetBranch"
                CheckReviewersAndCreatePR -sourceBranch $sourceBranch -targetBranch $newTargetBranch -title $title -description $description -reviewers $reviewers
            }
           })
       }

   } finally {
       Trace-VstsLeavingInvocation $MyInvocation
   }
}

function CreatePullRequest($body, $reviewers)
{
    Write-Host "The source branch is: $($body.sourceRefName)"
    Write-Host "The target branch is: $($body.targetRefName)"
    Write-Host "The title is: $($body.title)"
    Write-Host "The description is: $($body.description)"
    if($body.Keys -contains "reviewers")
    {
        Write-Host "The reviewers are: $($reviewers.Split(';'))"
    }
    $head = @{ Authorization = "Bearer $env:System_AccessToken" }
    $jsonBody = ConvertTo-Json $body
    $url = "$env:System_TeamFoundationCollectionUri$env:System_TeamProject/_apis/git/repositories/$env:Build_Repository_Name/pullrequests?api-version=5.0"
    $response =  Invoke-RestMethod -Uri $url -Method Post -Headers $head -Body $jsonBody -ContentType application/json
    if($response -ne $Null)
    {
        Write-Host "*************************"
        Write-Host "******** Success ********"
        Write-Host "*************************"
        Write-Host "Pull Request $($response.pullRequestId) created."
    }
}

function CheckReviewersAndCreatePR($sourceBranch, $targetBranch, $title, $description, $reviewers)
{
    if($reviewers -ne "")
    {
        Write-Host "not null"
        $url = "$($env:System_TeamFoundationCollectionUri)_apis/userentitlements?api-version=5.0-preview.2"
        $url = $url.Replace("//dev","//vsaex.dev")
        $head = @{ Authorization = "Bearer $env:System_AccessToken" }
        $users = Invoke-RestMethod -Uri $url -Method Get -ContentType application/json -Headers $head
        $reviewers = $reviewers.Split(';')
        $usersId = @()
        ForEach($reviewer in $reviewers)
        {
              $userId = $users.items.Where({ $_.user.mailAddress -eq $reviewer }).id
              $usersId += @{ id = "$userId" }
        }
        $body = @{
            sourceRefName = "$sourceBranch"
            targetRefName = "$targetBranch"
            title = "$title"
            description = "$description"
            reviewers = @( $usersId )
        }
        CreatePullRequest -body $body -reviewers $reviewers

    }
    else
    {
        $body = @{
            sourceRefName = "$sourceBranch"
            targetRefName = "$targetBranch"
            title = "$title"
            description = "$description"
        }
        CreatePullRequest -body $body
    }
}

RunTask
