# Docker Project Version

## Motivation
I've been moving more of our builds off of [Jenkins](https://www.jenkins.io/) and on to [Google Cloud Build (GCB)](https://cloud.google.com/cloud-build).
There are pros and cons when considering a move to GCB.

First the pros:
- It's a managed service which is affordably priced, and very easy to use. No infrastructure.
- Builds are easily tested using `gcloud builds submit .`, so no more changing, committing, and pushing to see if a pipeline works. But... there is no caching of `Dockerfile` build steps. So plan on debugging your `Dockerfile` builds locally.
- The "every step is simply a container" approach is so easy. There are other services that use this same approach, but none as elegantly as GCB. No time wasted writing plugins... just build a container image... like this.

Now, the cons:
- The UI is terrible. They've made enhancements lately, but it's still terrible by any reasonable measurement.
- I have to repeat myself with multiple triggers, because of their disparate support with building PRs, branches, and tags, and some limitation in the `cloudbuild.yaml` syntax. I really, really hate this aspect.
- Their focus seems to be on things that Google thinks we need, instead of what the community actually wants. I'm basing this on [issue feedback on GitHub](https://github.com/GoogleCloudPlatform/cloud-builders/issues/138), so consider this is mostly opinion. But the request for basic filtering by branch name with a single build trigger has been out there for years, and Google is reasonably cavalier in their response. As you can read, they were suprised by the request, signaling to me that they do no competitive market research, because every single competitor offers this feature.
- To do conditional logic, we have to rely on `bash` functionality, and this usually means overriding the container `entrypoint` and setting it to `bash` so we can do **IF THEN ELSE** logic. This clobbers thoughtful, easy to use build steps, and requires the engineer to understand the inner-workings of that build step. Of course it works, but it's not very Googley.
- And finally (the main point for this repo), is that GCB repository clones either don't clone the git repository at all (they copy it, using the GitHub app), or the checkout is so shallow that it's barely usable from a git perspective.

Through the years using [Gradle](https://gradle.org/) to build Java, Scala and Groovy projects, I've always used [Gradle plugins](https://plugins.gradle.org/) that automatically determine the `project.version` property based on the git history of commits and tags. When our CI/CD server simply copies the git repository instead of cloning it, we can't rely on using the git-ness of our repository at all. So I built this container image to use the GitHub API instead.

My process centers around Gradle, GitHub and Google Cloud Build, and that's what it's designed for. If your process needs to go in a different direction on any of these core pieces, PRs are welcome, and I would love to support them.

## Publish this build step to GCB
```
git clone https://github.com/RedPillAnalytics/docker-project-version
cd docker-project-version
gcloud builds submit .
# Bob's your uncle
```

## Implementation
I've done very little new development here... I'm standing on the shoulders of giants and cobbling together a few pieces of OSS with a small `entrypoint.sh` that uses them together.

- [Last Version](https://github.com/dvershinin/lastversion): This is the real brains of the operation. This is an incredibly smart CLI that can get the last version of a release/tag/whatever working with most of the different public repositories that they might be published to.
- [Semantic Versioning Tool](https://github.com/maykonlf/semver-cli): I didn't want to have to write the logic for bumping the different components of a semantic version, so `semver` handles this for me.
- [javaproperties-cli](https://javaproperties-cli.readthedocs.io/en/stable/index.html): A CLI for setting key=value pairs in property files. We use this to modify the `version` property in the `gradle.properties` file.
- [Gradle GitHub Release plugin](https://github.com/BreadMoirai/github-release-gradle-plugin): To close the loop on the entire process, we need to publish releases back to GitHub. I've been using this plugin for years with great results.
- [GitHub CLI](https://cli.github.com/): For non-Gradle releases, the GitHub CLI can be used instead to publish releases back to GitHub. You can use [our pre-built container](https://github.com/RedPillAnalytics/docker-gh) for dealing with GitHub CLI. This repository is built using this technique, so take a look at [the `cloudbuild.yaml` file](cloudbuild.yaml) as a sample. In this example, we don't actually build tags, but instead tag the image as part of the merge into master.

## cloudbuild.yaml
In our `cloudbuild.yaml` file, we include the `project-version` image as an early step, passing the built-in GCB variables `$REPO_NAME` and `BRANCH_NAME`:
```
- name: gcr.io/$PROJECT_ID/project-version
  id: version
  args:
   - $REPO_NAME
   - $BRANCH_NAME
  waitFor: ['-']
```

## GITHUB_TOKEN
Our GitHub personal access token needs to be provided as the environment variable `GITHUB_TOKEN` for `lastversion` to work correctly. We store this as a substitution variable, and pass it to the build with the `env` option in GCB:
```
options:
  env:
    - GITHUB_TOKEN=$_GITHUB_TOKEN
```

Additionally, we use `javaproperties` to write this value to the `gradle.properties` file as `githubToken` so it's available to the Gradle build. This is important for using `githubRelease` to publish our release back to GitHub:

```
githubRelease {
   token         githubToken
   owner         'RedPillAnalytics'
   repo          rootProject.name
   overwrite     true
   releaseAssets libsDir.listFiles()
}
```

## Standard Release
The build step in our `cloudbuild.yaml` file is enough to grab the latest release name from GitHub and parse the version number out of it. We then do the following:
* By default, we bump the *patch* portion of that semantic version (see [Pre-Release](#Pre-Release) for more options).
* If we aren't building the `master` or `main` branches , add `-SNAPSHOT` to the end of our version.
* Set `version` in the `gradle.properties` file using `javaproperties`.
* Write our version and tag to `stepvars/version` and `stepvars/tag` respectively in case we need them in other non-Gradle tools in subsequent build steps.

## Pre-Release
If we want to bump anything other than just the patch of our semantic version, then we simply create a [GitHub pre-release](https://docs.github.com/en/free-pro-team@latest/github/administering-a-repository/managing-releases-in-a-repository#creating-a-release). The build step knows to use this version number, whatever it is without bumping, for the next release, and sets all our markers accordingly. We just need to make sure we construct our `github-release` closure accordingly, ensuring we set `overwrite = true` to overwrite the pre-release with a real release.

```
githubRelease {
   token         githubToken
   owner         'RedPillAnalytics'
   repo          rootProject.name
   overwrite     true
   releaseAssets libsDir.listFiles()
}
```

## Samples

I hastily wrote this *"documentation"*, and realize that it needs more work. In the meantime, have a look at the `cloudbuild.yaml`, `build.gradle`, and `settings.gradle` files from our [Gradle Confluent](https://github.com/RedPillAnalytics/gradle-confluent) plugin as a working sample.
