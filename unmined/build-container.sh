#!/bin/bash
cd "$(dirname "${0}")"
TAG="${1}"
[ -n "${TAG}" ] || TAG="unmined:latest"
docker build . -t "${TAG}"
