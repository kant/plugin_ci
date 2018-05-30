#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CURDIR=$(pwd)

# GNU prefix command for mac os support (gsed, gsplit)
GP=
if [[ "$OSTYPE" =~ darwin* ]]; then
  GP=g
fi

export REPO_NAME=$(echo $TRAVIS_REPO_SLUG | ${GP}sed -r 's#^[^/]+/([^/]+)$#\1#')
export PLUGIN_NAME=$(echo $TRAVIS_REPO_SLUG | ${GP}sed -r 's#^[^/]+/(qgis_)?([^/]+)$#\2#')

# remove potential revision
export TAG_VERSION=${TRAVIS_TAG}
export RELEASE_VERSION=$(${GP}sed -r 's/-\w+$//; s/^v//' <<< ${TRAVIS_TAG})

# Inject metadata version from git tag
${GP}sed -r -i "s/^version=.*\$/version=${TRAVIS_TAG}/" $PLUGIN_NAME/metadata.txt

# Ensure DEBUG is False in main plugin file
${GP}sed -r -i 's/^DEBUG\s*=\s*True/DEBUG = False/' ${PLUGIN_NAME}/${PLUGIN_NAME}_plugin.py

${DIR}/../translate/update-translations.sh

# Tar up all the static files from the git directory
echo -e " \e[33mExporting plugin version ${TRAVIS_TAG} from folder ${PLUGIN_NAME}"
git archive --prefix=${PLUGIN_NAME}/ -o $PLUGIN_NAME-$RELEASE_VERSION.tar HEAD ${PLUGIN_NAME} #${TRAVIS_TAG}:${PLUGIN_NAME}

# Extract to a temporary location and add translations
TEMPDIR=/tmp/build-${PLUGIN_NAME}
mkdir -p ${TEMPDIR}/${PLUGIN_NAME}/${PLUGIN_NAME}/i18n
tar -xf ${PLUGIN_NAME}-${RELEASE_VERSION}.tar -C ${TEMPDIR}
mv i18n/*.qm ${TEMPDIR}/${PLUGIN_NAME}/${PLUGIN_NAME}/i18n

pushd ${TEMPDIR}/${PLUGIN_NAME}
zip -r ${CURDIR}/${PLUGIN_NAME}-${TAG_VERSION}.zip ${PLUGIN_NAME}
popd

echo "## Detailed changelod" > /tmp/changelog
git log HEAD^...$(git describe --abbrev=0 --tags HEAD^) --pretty=format:"### %s%n%n%b" >> /tmp/changelog

${DIR}/publish_release.py -f ${CURDIR}/${PLUGIN_NAME}-${TAG_VERSION}.zip -c /tmp/changelog -o /tmp/release_notes
cat /tmp/release_notes
${DIR}/publish_plugin.py -u "${OSGEO_USERNAME}" -w "${OSGEO_PASSWORD}" -r "${TRAVIS_TAG}" ${PLUGIN_NAME}-${TAG_VERSION}.zip -c /tmp/release_notes
