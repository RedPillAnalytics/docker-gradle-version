#!/usr/bin/env bash
repo=$1
branch=$2
alpha=`lastversion --pre $1`
stable=`lastversion $1`
if [[ $alpha == $stable ]]
then
  semver init --release $stable
  semver up release > /dev/null
else
  semver init --release $alpha
fi
version=`semver get release`
if [[ $2 != "master" && $2 != "main" ]]
then
  version=$version-SNAPSHOT
fi
version="${version:1}"
echo version = $version >> gradle.properties
echo $version

# echo "Tests:"
# cat gradle.properties
# cat .semver.yaml
