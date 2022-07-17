import tl = require('azure-pipelines-task-lib/task');

const repoTypeInputVariableName = 'repoType';
const githubEndpointInputVariableName = 'githubEndpoint';
const repositorySelectorInputVariableName = 'repositorySelector';
const githubRepositoryInputVariableName = 'githubRepository';
const projectIdInputVariableName = 'projectId';
const gitRepositoryIdInputVariableName = 'gitRepositoryId';
const isForkedInputVariableName = 'isForked';
const sourceBranchInputVariableName = 'sourceBranch';
const targetBranchInputVariableName = 'targetBranch';
const titleInputVariableName = 'title';
const descriptionInputVariableName = 'description';
const reviewersInputVariableName = 'reviewers';
const tagsInputVariableName = 'tags';
const isDraftInputVariableName = 'isDraft';
const linkWorkItemsInputVariableName = 'linkWorkItems';
const passPullRequestIdBackToADOInputVariableName = 'passPullRequestIdBackToADO';
const autoCompleteInputVariableName = 'autoComplete';
const githubAutoMergeInputVariableName = 'githubAutoMerge';
const mergeStrategyInputVariableName = 'mergeStrategy';
const githubMergeStrategyInputVariableName = 'githubMergeStrategy';
const deleteSourceInputVariableName = 'deleteSource';
const githubDeleteSourceBranchInputVariableName = 'githubDeleteSourceBranch';
const commitMessageInputVariableName = 'commitMessage';
const githubMergeCommitTitleInputVariableName = 'githubMergeCommitTitle';
const githubMergeCommitMessageInputVariableName = 'githubMergeCommitMessage';
const transitionWorkItemsInputVariableName = 'transitionWorkItems';
const bypassPolicyInputVariableName = 'bypassPolicy';
const bypassReasonInputVariableName = 'bypassReason';
const alwaysCreatePrInputVariableName = 'alwaysCreatePr';
const usePshInputVariableName = 'usePsh';

async function run() {
    try {
        const repoType = tl.getInput(repoTypeInputVariableName, true);
        const githubEndpoint = tl.getInput(githubEndpointInputVariableName, repoType == 'GitHub');
        const repositorySelector = tl.getInput(repositorySelectorInputVariableName, repoType == 'Azure DevOps');
        const githubRepository = tl.getInput(githubRepositoryInputVariableName, repoType == 'GitHub');
        const projectId = tl.getInput(projectIdInputVariableName, repositorySelector == 'select');
        const gitRepositoryId = tl.getInput(gitRepositoryIdInputVariableName, repositorySelector == 'select');
        const isForked = tl.getBoolInput(isForkedInputVariableName, repositorySelector == 'select');
        const sourceBranch = tl.getInputRequired(sourceBranchInputVariableName);
        const targetBranch = tl.getInputRequired(targetBranchInputVariableName);
        const title = tl.getInputRequired(titleInputVariableName);
        const description = tl.getInput(descriptionInputVariableName);
        const reviewers = tl.getInput(reviewersInputVariableName);
        const tags = tl.getInput(tagsInputVariableName);
        const isDraft = tl.getBoolInput(isDraftInputVariableName);
        const linkWorkItems = tl.getBoolInput(linkWorkItemsInputVariableName);
        const passPullRequestIdBackToADO = tl.getBoolInput(passPullRequestIdBackToADOInputVariableName);
        const autoComplete = tl.getBoolInput(autoCompleteInputVariableName);
        const githubAutoMerge = tl.getBoolInput(githubAutoMergeInputVariableName);
        const mergeStrategy = tl.getInput(mergeStrategyInputVariableName);
        const githubMergeStrategy = tl.getInput(githubMergeStrategyInputVariableName);
        const deleteSource = tl.getBoolInput(deleteSourceInputVariableName);
        const githubDeleteSourceBranch = tl.getBoolInput(githubDeleteSourceBranchInputVariableName);
        const commitMessage = tl.getInput(commitMessageInputVariableName);
        const githubMergeCommitTitle = tl.getInput(githubMergeCommitTitleInputVariableName);
        const githubMergeCommitMessage = tl.getInput(githubMergeCommitMessageInputVariableName);
        const transitionWorkItems = tl.getBoolInput(transitionWorkItemsInputVariableName);
        const bypassPolicy = tl.getBoolInput(bypassPolicyInputVariableName);
        const bypassReason = tl.getInput(bypassReasonInputVariableName);
        const alwaysCreatePr = tl.getBoolInput(alwaysCreatePrInputVariableName);
        const usePsh = tl.getBoolInput(usePshInputVariableName);

        let executable = "pwsh";

        if (tl.getVariable("AGENT.OS") === "Windows_NT") {
            if (usePsh) {
                executable = "powershell.exe";
            }

            console.log(`Using executable '${executable}'`);
        } else {
            console.log(`Using executable '${executable}' as only option on '${tl.getVariable("AGENT.OS")}'`);
        }

        var args = [
            __dirname + "/createPullRequest.ps1"
        ];

        args.push("-sourceBranch");
        args.push(sourceBranch);

        args.push("-targetBranch");
        args.push(targetBranch);

        args.push("-title");
        args.push(title);

        args.push("-description");
        args.push(description || '');

        args.push("-reviewers");
        args.push(reviewers || '');

        args.push("-tags");
        args.push(tags || '');

        if (isDraft) {
            args.push("-isDraft");
        }

        if (autoComplete) {
            args.push("-autoComplete");
        }

        args.push("-mergeStrategy");
        args.push(mergeStrategy || '');

        if (deleteSource) {
            args.push("-deleteSource");
            args.push("-deleteSourch");
        }

        args.push("-commitMessage");
        args.push(commitMessage || '');

        if (transitionWorkItems) {
            args.push("-transitionWorkItems");
        }

        if (linkWorkItems) {
            args.push("-linkWorkItems");
        }

        args.push("-teamProject");
        args.push(projectId || '');

        args.push("-repositoryName");
        args.push(gitRepositoryId || '');

        args.push("-githubRepository");
        args.push(githubRepository || '');

        if (passPullRequestIdBackToADO) {
            args.push("-passPullRequestIdBackToADO");
        }

        if (isForked) {
            args.push("-isForked");
        }

        if (bypassPolicy) {
            args.push("-bypassPolicy");
        }

        args.push("-bypassReason");
        args.push(bypassReason || '');

        if (alwaysCreatePr) {
            args.push("-alwaysCreatePR");
        }

        if (githubAutoMerge) {
            args.push("-githubAutoMerge");
        }

        args.push("-githubMergeCommitTitle");
        args.push(githubMergeCommitTitle || '');

        args.push("-githubMergeCommitMessage");
        args.push(githubMergeCommitMessage || '');

        args.push("-githubMergeStrategy");
        args.push(githubMergeStrategy || '');

        if (githubDeleteSourceBranch) {
            args.push("-githubDeleteSourceBranch");
        }

        console.log(`${executable} ${args.join(" ")}`);

        var spawn = require("child_process").spawn;

        spawn(executable, args);
    }
    catch (err) {
        let errorMessage = "Unknown error";

        if (err instanceof Error) {
            errorMessage = err.message;
        }

        tl.setResult(tl.TaskResult.Failed, errorMessage);
    }
}

run();