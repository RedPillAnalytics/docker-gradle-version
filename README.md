# Docker Project Version

## Inspiration
I've been moving more of our builds off of [Jenkins](https://www.jenkins.io/) and on to [Google Cloud Build (GCB)](https://cloud.google.com/cloud-build).
There are a lot of pros and cons when considering a move to GCB.

First the pros:
- It's a managed service which is affordably priced.
- Builds can be easily tested using `gcloud builds submit`, so no more changing, committing, and pushing to see if workflows are working.
- The "every step is simply a container" approach is so easy. Of course, other services use this same approach, but none as elegantly as GCB.

Now, the cons:
- The UI is terrible. They've made enhancements lately, but it's still terrible but any reasonable measurement.
- There focus seems to be on things that Google want, not on what the community wants. I'm basing this solely on GitHub feedback, so consider the source is mostly opinion.
- I have to repeat myself often with multiple `cloudbuild.yaml` files and multiple triggers, because of their desperate support with building PRs, branches, and tags. I really, really hate this aspect.
- And finally (the main point for this repo), is that repository clones either don't checkout a git repository at all (GitHub app), or the checkout is so shallow that there's nothing usable there.

Through the years using [Gradle](https://gradle.org/) to build Java projects, I've always used [Gradle plugins](https://plugins.gradle.org/) that automatically determine the `project.version` property based on the git history of commits and tags. When our CI/CD server simply copies the git repository instead of cloning it, we can't rely on using the git-ness of our repository at all. So I built this container image to use the Git providers APIs instead.

My process centers around Java, Gradle, GitHub and Google Cloud Build, and that's what it's designed for. If your process needs to go in a different direction on any of these pieces, PRs are welcome.

## Implementation
There is very little new development here actually... I'm standing on the shoulders of giants and cobbling together a few magnificent pieces of OSS with a small `entrypoint.sh` that uses them together.

- [Last Version](https://github.com/dvershinin/lastversion): This is the real brains of the operation. This is an incredibly smart CLI that can get the last version of a release/tag/whatever working with most of the different cloud services that they might be published to.
- [Semantic Versioning Tool](https://github.com/maykonlf/semver-cli): I didn't want to have to code the logic for bumping a semantic version, so `semver` handles this for me.
- [Gradle File Version plugin](https://github.com/epitschke/gradle-file-versioning): I needed an easy hand-off point between my container image and Gradle, and this plugin made that very simple. I can write the expected output to that file, and with this plugin applied to my Gradle project, the version flows through transparently with no fuss.
- [Gradle GitHub Release plugin](https://github.com/BreadMoirai/github-release-gradle-plugin): To close the loop on the entire process, we need to publish releases back to GitHub. I've been using this plugin for years with great results.

## Standard Release

In our `cloudbuild.yaml` file, we include the `project-version` image as an early step, passing the build-in GCB variables `$REPO_NAME` and `BRANCH_NAME`:
```
- name: gcr.io/$PROJECT_ID/project-version
  id: version
  args:
   - $REPO_NAME
   - $BRANCH_NAME
  waitFor: ['-']
```

This is enough to to grab the latest release from GitHub, set the Gradle version using the `gradle-file-versioning` plugin. Nothing else has to be done. By default, the image with bump the patch of our version. If we aren't building the `master` , then the image will automatically add `-SNAPSHOT` to the end of the version. I add the `version.txt` file that `gradle-file-versioning` uses to my `.gitignore` file. I know the purpose of that plugin was to version this file in the repo, but since I pull the latest release from GitHub, there is no reason to have it there.

## Pre-Release
If we want to bump anything other than just the patch, then we simply create a GitHub pre-release. The container knows to use this version number, whatever it is, for the next release, and sets the Gradle version accordingly. We just need to make sure we construct our `github-release` closure accordingly, ensuring we set `overwrite = true`.

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

I hastily wrote this "documentation", and realize that it needs more work. In the meantime, have a look at the `cloudbuild.yaml`, `build.gradle`, and `settings.gradle` files from our [Gradle Confluent](https://github.com/RedPillAnalytics/gradle-confluent) as samples.
