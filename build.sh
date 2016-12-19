#!/bin/bash
set -o pipefail
IFS=$'\n\t'

DOCKER_SOCKET=/var/run/docker.sock

if [ ! -e "${DOCKER_SOCKET}" ]; then
  echo "Docker socket missing at ${DOCKER_SOCKET}"
  exit 1
fi

if [ -z "${SOURCE_REF}" ]; then
  echo "SOURCE_REF is required"
  exit 1
fi

if [[ -d /var/run/secrets/openshift.io/push ]] && [[ ! -e /root/.ssh/id_rsa ]]; then
  cp /var/run/secrets/openshift.io/push/.ssh/id_rsa /root/.ssh/id_rsa
fi

if [[ -d /var/run/secrets/openshift.io/push ]] && [[ ! -e /root/.docker/config.json ]]; then
  cp /var/run/secrets/openshift.io/push/.docker/config.json /root/.docker/config.json
fi


if [ -n "${OUTPUT_IMAGE}" ]; then
  TAG="${OUTPUT_REGISTRY}/${OUTPUT_IMAGE}"
fi

if [[ "${SOURCE_URI}" != "git://"* ]] && [[ "${SOURCE_URI}" != "git@"* ]]; then
  URL="${SOURCE_URI}"
  if [[ "${URL}" != "http://"* ]] && [[ "${URL}" != "https://"* ]]; then
    URL="https://${URL}"
  fi
  curl --head --silent --fail --location --max-time 16 $URL > /dev/null
  if [ $? != 0 ]; then
    echo "Could not access source url: ${SOURCE_URI}"
    exit 1
  fi
fi

BUILD_DIR=$(mktemp --directory)
git clone --recursive "${SOURCE_URI}" "${BUILD_DIR}"
if [ $? != 0 ]; then
  echo "Error trying to fetch git source: ${SOURCE_URI}"
  exit 1
fi
pushd "${BUILD_DIR}"
git checkout "${SOURCE_REF}"
if [ $? != 0 ]; then
  echo "Error trying to checkout branch: ${SOURCE_REF}"
  exit 1
fi

echo "Determining builder"
if [ -f "build.gradle" ]; then
  echo "Found build.gradle"
  BUILDER=gradle
  BUILD_ARGS=${GRADLE_ARGS:-${BUILD_ARGS:-"build"}}
  DOCKERFILE_DIR=${DOCKERFILE_DIR:-build/docker/}
  if [ -f "gradlew" ]; then
    echo "---> Building application with wrapper..."
    BUILDER="./gradlew"
  fi
fi

#TODO: Add additional builder support

if [ -z "$BUILDER" ]; then
  echo "---> Could not determine builder"
  exit 1
fi

echo "---> Building application from source..."
BUILD_ARGS=${BUILD_ARGS:-"build"}
echo "--> # BUILDER = $BUILDER"
echo "--> # BUILD_ARGS = $BUILD_ARGS"

echo "---> Building application with..."
echo "--------> $BUILDER $BUILD_ARGS"
bash -c "${BUILDER} ${BUILD_ARGS}"

if [ $? != 0 ]; then
  echo "Error building code using: $BUILDER $BUILD_ARGS"
  exit 1
fi

popd

DOCKERFILE_DIR="${BUILD_DIR}/${DOCKERFILE_DIR}"
if [ ! -d "${DOCKERFILE_DIR}" ]; then
  echo "Unable to find Dockerfile directory at '${DOCKERFILE_DIR}'"
  exit 1
fi

if [ ! -e "${DOCKERFILE_DIR}/Dockerfile" ]; then
  echo "Expected Dockerfile at '${DOCKERFILE_DIR}'"
  exit 1
fi

docker build --rm -t "${TAG}" "${DOCKERFILE_DIR}"

if [ $? != 0 ]; then
  echo "Error building docker image: ${TAG} ${DOCKERFILE_DIR}"
  exit 1
fi

if [ -n "${OUTPUT_IMAGE}" ] || [ -s "/root/.docker/config.json" ]; then
  docker push "${TAG}"
fi
