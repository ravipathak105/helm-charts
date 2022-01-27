#!/usr/bin/env bash
set -x
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

pwd=$(pwd)
cr="docker run -v ${pwd}/docs:/cr quay.io/helmpack/chart-releaser:v${CR_VERSION}"
gitlab_repo="https://${GITLAB_USER}:${GITLAB_TOKEN}@${INTERNAL_GITLAB_URL}/devops-program/helm-charts"
github_repo="helm-charts-test"
helm_repo="https://helm.pingidentity.com/"
chart="charts/ping-devops"

git clone -b "${CI_COMMIT_BRANCH}" "${gitlab_repo}"
cd helm-charts || exit

function package_chart() {
    echo "Packaging chart '${chart}'..."
    helm package ${pwd}/${chart} --destination ${pwd}/docs/.chart-packages || exit 1
}

function upload_packages() {
    echo "Uploading chart packages for ${chart}..."
    ${cr} upload -o ${GITHUB_OWNER} -r ${github_repo} --token ${GITHUB_TOKEN} --package-path /cr/.chart-packages || exit 1
}

function update_chart_index() {
    echo "Generating chart index for ${chart}..."
    ${cr} index -o ${GITHUB_OWNER} -r ${github_repo} -c ${helm_repo} --token ${GITHUB_TOKEN} --index-path /cr/index.yaml --package-path /cr/.chart-packages || exit 1
}

function publish_charts() {
    #change this to the real repo
    git clone "https://${GITHUB_OWNER}:${GITHUB_TOKEN}@github.com/wesleymccollam/helm-charts-test.git"
    git config user.email "${GITHUB_OWNER}@pingidentity.com"
    git config user.name "${GITHUB_OWNER}"
    git checkout -b $CI_COMMIT_BRANCH || exit
    yes | cp ${pwd}/docs/index.yaml helm-charts-test/docs/index.yaml
    cd helm-charts-test
    git add docs/index.yaml
    git commit -m="Release $CI_COMMIT_BRANCH"
    git remote add gh_location "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/wesleymccollam/helm-charts-test.git"
    if test -n "$CI_COMMIT_TAG"; then
        git push gh_location "$CI_COMMIT_TAG"
    fi
    git push gh_location master
}

# install cr
docker pull quay.io/helmpack/chart-releaser:v${CR_VERSION}

package_chart ${chart}
upload_packages
update_chart_index
publish_charts
