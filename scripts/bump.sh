#!/bin/bash
set -eu -o pipefail
cd "$(dirname "$0")"/..

log () { echo "[$(date +%Y-%m-%dT%H:%M:%S%Z)]" "$@"; }

: ${BRANCH_TO_BUILD:=main}
: ${PR_REVIEWERS:=mattermost/core-build-engineers}
: ${BUMP_BUILD_NUMBER:=}    # You can optionally specify the BUILD_NUMBER variable for selecting the next build number
                            # If you don't, then the Fastlane action will pick the next build number automatically
: ${BUMP_VERSION_NUMBER:=}  # If enabled, you must populate the VERSION variable as well
: ${CREATE_PR:=}            # Enable CREATE_PR to push the commit to origin, and create a corresponding PR
: ${PR_EXTRA_MESSAGE:=}     # Optional message to add in the PR description
: ${GIT_LOCAL_BRANCH:=chore-bump-${BRANCH_TO_BUILD}-$(date +%s)}

log "Checking that the configuration is sane"
if [ -z "${BUMP_BUILD_NUMBER}" -a -z "${BUMP_VERSION_NUMBER}" ]; then
  log "Error: you must set at least one between BUMP_BUILD_NUMBER and BUMP_VERSION_NUMBER" >&2
  exit 1
fi
if [ -n "$BUMP_VERSION_NUMBER" ]; then
  : ${VERSION:?Setting this variable is required when BUMP_VERSION_NUMBER is set.}
  VERSION_REGEXP='^[0-9]+\.[0-9]+\.[0-9]+$'
  if ! grep -qE $VERSION_REGEXP"" <<<$VERSION; then
    log "Error: the VERSION variable value should match regexp '$VERSION_REGEXP'. Aborting." >&2
    exit 2
  fi
fi

log "Asserting that the workdir is clean"
if ! git diff --quiet; then
  log "Error: workdir is not clean. Aborting" >&2
  exit 3
fi

log "Saving the currently checked out branch"
CURRENT_BRANCH=$(git branch --show-current)
trap "git checkout $CURRENT_BRANCH" EXIT

log "Creating branch '${GIT_LOCAL_BRANCH}' based on branch '$BRANCH_TO_BUILD'"
git checkout $BRANCH_TO_BUILD
git pull
git checkout -b $GIT_LOCAL_BRANCH

log "Generating env file required by Fastlane..."
tee .env <<EOF
export BRANCH_TO_BUILD=${BRANCH_TO_BUILD}
export GIT_LOCAL_BRANCH=${GIT_LOCAL_BRANCH}
export COMMIT_CHANGES_TO_GIT=true
$([ -n "$BUMP_BUILD_NUMBER" ] && echo "\
export INCREMENT_BUILD_NUMBER=true
" || :)
$([ -n "$BUMP_BUILD_NUMBER" -a -n "${BUILD_NUMBER:-}" ] && echo "\
export BUILD_NUMBER=${BUILD_NUMBER}
" || :)
$([ -n "$BUMP_VERSION_NUMBER" ] && echo "\
export INCREMENT_VERSION_NUMBER=true
export VERSION=${VERSION}
" || :)
EOF

if [ -n "$BUMP_BUILD_NUMBER" ]; then
  log "Bumping build number..."
  (. .env && cd fastlane && bundle install && CI=true bundle exec set_app_build_number)
fi

if [ -n "$BUMP_VERSION_NUMBER" ]; then
  log "Bumping version number..."
  (. .env && cd fastlane && bundle install && CI=true bundle exec set_app_version)
fi

if [ -n "${CREATE_PR}" ]; then
  log "Pushing branch ${GIT_LOCAL_BRANCH}, and creating a corresponding PR to ${BRANCH_TO_BUILD}"
  git push origin ${GIT_LOCAL_BRANCH}

  log "Creating PR"
  PR_TITLE="Bump app ${BUMP_BUILD_NUMBER:+build}${BUMP_VERSION_NUMBER:+${BUMP_BUILD_NUMBER:+ and }version} number"
  gh pr create \
    --repo mattermost/mattermost-mobile \
    --base main \
    --head "${GIT_LOCAL_BRANCH}" \
    --reviewer "${PR_REVIEWERS}" \
    --title "$PR_TITLE" \
    $([ -z "$BUMP_VERSION_NUMBER" ] || echo -n "--milestone v${VERSION} --label CherryPick/Approved") \
    --body-file - <<EOF
#### Summary
$([ -z "$BUMP_BUILD_NUMBER" ] || echo "\
Bump app build number to ${BUILD_NUMBER:-immediately next available}
")
$([ -z "$BUMP_VERSION_NUMBER" ] || echo "\
Bump app version number to ${VERSION}
")
${PR_EXTRA_MESSAGE}

#### Release Note
\`\`\`release-note
NONE
\`\`\`
EOF
else
  log "Skipping branch push and PR creation. Run with CREATE_PR=yes to perform those operations."
fi
