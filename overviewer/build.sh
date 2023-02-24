#!/bin/bash
set -e
TAG_TMP="overviewer-build:tmp-$(uuidgen)"

cd "$(dirname "${0}")"
docker build . -t "${TAG_TMP}"
docker tag "${TAG_TMP}" "overviewer-build:latest"

if [ -n "${ECR_REPO}" ] ; then
  aws ecr get-login-password | docker login --username AWS --password-stdin "${ECR_REPO}"
  docker tag "${TAG_TMP}" "${ECR_REPO}"
  docker push "${ECR_REPO}"
  for USER_TAG in "${TAGS[@]}" ; do
    docker tag "${TAG_TMP}" "${ECR_REPO}:${USER_TAG}"
    docker push "${ECR_REPO}:${USER_TAG}"
    docker rmi --force "${ECR_REPO}:${USER_TAG}"
  done
  docker rmi "${ECR_REPO}" "${TAG_TMP}" 
else
  echo "This image version has been tagged ${TAG_TMP}"
fi
echo "Image tagged as overviewer-build:latest"
