#!/bin/bash

# config
with_v=${WITH_V:-false}
# get latest tag
git checkout master
git pull
tag=$(git tag --sort=-creatordate | head -n 1)
echo ::tag before latest check: $tag
tag_commit=$(git rev-list -n 1 $tag)
# get current commit hash for tag
commit=$(git rev-parse HEAD)
git_refs_url=$(jq .repository.git_refs_url $GITHUB_EVENT_PATH | tr -d '"' | sed 's/{\/sha}//g')
if [ "$tag_commit" == "$commit" ]; then
    echo "No new commits since previous tag. Skipping..."
    exit 0
fi
if [ "$tag" == "latest" ]; then
    tag=$(git tag --sort=-creatordate | head -n 2 | tail -n 1)
fi
echo ::tag before update: $tag
# if there are none, start tags at 0.0.0
if [ -z "$tag" ]
then
    log=$(git log --pretty=oneline)
    tag=0.0.0
else
    log=$(git log $tag..HEAD --pretty=oneline)
fi
echo ::commit message: $log
# get commit logs and determine home to bump the version
# supports #major, #minor, #patch (anything else will be 'minor')
case "$log" in
    *#major* ) new=$(semver bump major $tag);;
    *#minor* ) new=$(semver bump minor $tag);;
    *#patch* ) new=$(semver bump patch $tag);;
    * ) new="none";;
esac
echo ::setting user and email
git config user.email "fake@email.com" 
git config user.name "user"
echo ::checking if new tag exists
if [ "$new" != "none" ]; then
	# prefix with 'v'
	if $with_v
	then
	    new="v$new"
	fi
	echo ::new tag: $new

	# push new tag ref to github
	dt=$(date '+%Y-%m-%dT%H:%M:%SZ')
	full_name=$GITHUB_REPOSITORY

	echo "$dt: **pushing tag $new to repo $full_name"
		
	#curl -s -X POST $git_refs_url \
	#-H "Authorization: token $GITHUB_TOKEN" \
	#-d '{"ref": "refs/tags/'$new'", "sha": "'$commit'"}'
	git tag -a -m "release: ${new}" $new $commit
fi	

echo ::pushing new tag
git push origin :refs/tags/latest
git tag -fa -m "latest release" latest $commit
git push --follow-tag
