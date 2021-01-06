# Docker Project Version

## Motivation
I've been moving more of our builds off of [Jenkins](https://www.jenkins.io/) and on to [Google Cloud Build (GCB)](https://cloud.google.com/cloud-build).
There are a lot of pros and cons when considering a move to GCB.

First the pros:
- It's a managed service which is affordably priced, and very easy to use. No infrastructure.
- Builds are easily tested using `gcloud builds submit`, so no more changing, committing, and pushing to see if our pipelines are working.
- The "every step is simply a container" approach is so easy. Of course, other services use this same approach, but none as elegantly as GCB.

Now, the cons:
- The UI is terrible. They've made enhancements lately, but it's still terrible by any reasonable measurement.
- Their focus seems to be on things that Google wants, not on what the community wants. I'm basing this solely on GitHub feedback, so consider the source is mostly opinion.
- I have to repeat myself often with multiple `cloudbuild.yaml` files and multiple triggers, because of their disparate support with building PRs, branches, and tags, and some limitation in the `cloudbuild.yaml` syntax. I really, really hate this aspect.
- And finally (the main point for this repo), is that GCB repository clones either don't checkout a git repository at all (using the GitHub app), or the checkout is so shallow that it's barely usable.

Through the years using [Gradle](https://gradle.org/) to build Java, Scala and Groovy projects, I've always used [Gradle plugins](https://plugins.gradle.org/) that automatically determine the `project.version` property based on the git history of commits and tags. When our CI/CD server simply copies the git repository instead of cloning it, we can't rely on using the git-ness of our repository at all. So I built this container image to use the GitHub API instead.

My process centers around Gradle, GitHub and Google Cloud Build, and that's what it's designed for. If your process needs to go in a different direction on any of these pieces, PRs are welcome, and I would love to support them.

## Implementation
I've done very little new development here... I'm standing on the shoulders of giants and cobbling together a few magnificent pieces of OSS with a small `entrypoint.sh` that uses them together.

- [Last Version](https://github.com/dvershinin/lastversion): This is the real brains of the operation. This is an incredibly smart CLI that can get the last version of a release/tag/whatever working with most of the different public repositories that they might be published to.
- [Semantic Versioning Tool](https://github.com/maykonlf/semver-cli): I didn't want to have to write the logic for bumping the different components of a semantic version, so `semver` handles this for me.
- [javaproperties-cli](https://javaproperties-cli.readthedocs.io/en/stable/index.html): A CLI for setting key=value pairs in property files. We use this to modify the `version` property in the `gradle.properties` file.
- [Gradle GitHub Release plugin](https://github.com/BreadMoirai/github-release-gradle-plugin): To close the loop on the entire process, we need to publish releases back to GitHub. I've been using this plugin for years with great results.

## Standard Release

In our `cloudbuild.yaml` file, we include the `project-version` image as an early step, passing the built-in GCB variables `$REPO_NAME` and `BRANCH_NAME`:
```
- name: gcr.io/$PROJECT_ID/project-version
  id: version
  args:
   - $REPO_NAME
   - $BRANCH_NAME
  waitFor: ['-']
```

This build step is enough to grab the latest release from GitHub, and set it in the `gradle.properties` file using `javaproperties`.
By default, this build step will bump the patch portion of the `version` property.
If we aren't building the `master` or `main` branches , then the image will automatically add `-SNAPSHOT` to the end of the version.

## Pre-Release
If we want to bump anything other than just the patch of our semantic version, then we simply create a GitHub pre-release. The build step knows to use this version number, whatever it is without bumping, for the next release, and sets the Gradle version accordingly. We just need to make sure we construct our `github-release` closure accordingly, ensuring we set `overwrite = true` to overwrite the pre-release with a real release.

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
