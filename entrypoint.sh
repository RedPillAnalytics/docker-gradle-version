#!/usr/bin/env bash

# get file inputs
repo=$1
branch=$2
stepvars="stepvars"
tagfile="${stepvars}/tag.txt"
versionfile="${stepvars}/version.txt"

# properties files
properties="gradle.properties"

# grab the stable and alpha versions from GitHub
alpha=`lastversion --pre $1`
stable=`lastversion $1`

# just in case it exists already
rm -f .semver.yaml

# If there is no alpha version, then bump
if [[ $alpha == $stable ]]
then
  semver init --release $stable
  semver up release > /dev/null
# If there is an alpha version, use that
else
  semver init --release $alpha
fi

# get the modified version
tag=`semver get release`

# neet to add pre-release marker to non-main branches
if [[ $2 != "master" && $2 != "main" ]]
then
  tag=$tag-SNAPSHOT
fi

# write to a file for access across steps
echo $tag > $tagfile

# get non-tag version
version="${tag:1}"
# write to a file for access across steps
echo $version > $versionfile

# create the gradle.properties file if it isn't there
touch $properties

# update the version property
javaproperties set -o props.temp $properties version $version
mv props.temp $properties
echo $tag
