#!/bin/bash

REPO_NAME=$(echo ${TRAVIS_REPO_SLUG} | cut -d/ -f2)
OWNER_NAME=$(echo ${TRAVIS_REPO_SLUG} | cut -d/ -f1)
GIT_REVISION=$(git log --pretty=format:'%h' -n 1)
LAST_COMMIT_AUTHOR=$(git log --pretty=format:'%an' -n1)
HEADNAME=$(git rev-parse --abbrev-ref HEAD)

if [[ ${TRAVIS_PULL_REQUEST} == "false" ]]; then

    make && ./upload-assets.sh -f --travis --nxlog-scripts --widgets --manifests --cookbooks $GIT_REVISION

    (
        export LOGGER_VERSION=$GIT_REVISION
        cd test;
        python test_runner.py
    )

    # if tests pass, publish fresh artifacts
    # if [ $? == 0 ] && [ x$HEADNAME != xHEAD ]; then
    #     ./upload-assets.sh -f --nxlog-scripts --widgets --manifests --cookbooks $HEADNAME
    # fi

fi
