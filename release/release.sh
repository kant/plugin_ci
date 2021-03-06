#!/usr/bin/env bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CURDIR=$(pwd)

# GNU prefix command for mac os support (gsed, gsplit)
GP=
if [[ "$OSTYPE" =~ darwin* ]]; then
  GP=g
fi

if [[ ! ${TRAVIS_SECURE_ENV_VARS} == "true" || -z ${TRAVIS_TAG} ]]; then
  echo "Not releasing: not on main repo or master branch or missing tag"
  exit 1
fi

source ${DIR}/../scripts/env_variables.sh

# Inject metadata version from git tag
${GP}sed -r -i "s/^version=.*\$/version=${RELEASE_VERSION}/" ${PLUGIN_SRC_DIR}/metadata.txt

# Ensure DEBUG is False in main plugin file
if [[ -f ${PLUGIN_SRC_DIR}/${PLUGIN_REPO_NAME}_plugin.py ]]; then
  ${GP}sed -r -i 's/^DEBUG\s*=\s*True/DEBUG = False/' ${PLUGIN_SRC_DIR}/${PLUGIN_REPO_NAME}_plugin.py
fi

if [[ -d .tx ]]; then
  # Pull translations from transifx
  ${DIR}/../translate/pull-transifex-translations.sh
  ${DIR}/../translate/compile-strings.sh i18n/*.ts
else
  echo -e "\033[0;33mNo .tx folder present in repository, not pulling any translations\033[0m"
fi

# Tar up all the static files from the git directory
echo -e " \e[33mExporting plugin version ${TRAVIS_TAG} from folder ${PLUGIN_SRC_DIR}"
# create a stash to save uncommitted changes (metadata)
STASH=$(git stash create)
git archive --prefix=${PLUGIN_REPO_NAME}/ -o ${CURDIR}/${PLUGIN_REPO_NAME}-${RELEASE_VERSION}.tar ${STASH} ${PLUGIN_SRC_DIR}

# include submodules as part of the tar
echo "also archive submodules..."
git submodule foreach | while read entering path; do
    temp="${path%\'}"
    temp="${temp#\'}"
    path=${temp}
    [ "$path" = "" ] && continue
    [[ ! "$path" =~ ^"${PLUGIN_SRC_DIR}" ]] && echo "skipping non-plugin submodule $path" && continue
    pushd ${path} > /dev/null
    git archive --prefix=${PLUGIN_REPO_NAME}/${path}/ HEAD > /tmp/tmp.tar
    tar --concatenate --file=${CURDIR}/${PLUGIN_REPO_NAME}-${RELEASE_VERSION}.tar /tmp/tmp.tar
    rm /tmp/tmp.tar
    popd > /dev/null
done

# Extract to a temporary location and add translations
TEMPDIR=/tmp/build-${PLUGIN_REPO_NAME}
mkdir -p ${TEMPDIR}/${PLUGIN_REPO_NAME}/${PLUGIN_REPO_NAME}/i18n
tar -xf ${CURDIR}/${PLUGIN_REPO_NAME}-${RELEASE_VERSION}.tar -C ${TEMPDIR}
if [[ "${PLUGIN_SRC_DIR}" != "${PLUGIN_REPO_NAME}" ]]; then
  mv ${TEMPDIR}/${PLUGIN_REPO_NAME}/${PLUGIN_SRC_DIR}/* ${TEMPDIR}/${PLUGIN_REPO_NAME}/${PLUGIN_REPO_NAME}
  rmdir ${TEMPDIR}/${PLUGIN_REPO_NAME}/${PLUGIN_SRC_DIR}
fi
if [[ -d i18n ]]; then
  mv i18n/*.qm ${TEMPDIR}/${PLUGIN_REPO_NAME}/${PLUGIN_REPO_NAME}/i18n
else
  if [[ -d .tx ]]; then
    echo -e "\033[0;33mNo i18n folder is present, even though transifex is. Something seems to be going wrong.\033[0m"
  fi
fi

pushd ${TEMPDIR}/${PLUGIN_REPO_NAME}
zip -r ${CURDIR}/${ZIPFILENAME} ${PLUGIN_REPO_NAME}
popd

echo "## Detailed changelog" > /tmp/changelog
git log HEAD^...$(git describe --abbrev=0 --tags HEAD^) --pretty=format:"### %s%n%n%b" >> /tmp/changelog

CHANGELOG_OPTION=""
if [[ "$APPEND_CHANGELOG" = "true" ]]; then
  CHANGELOG_OPTION="-c /tmp/changelog"
fi


${DIR}/create_release.py -f ${CURDIR}/${ZIPFILENAME} ${APPEND_CHANGELOG:+-c /tmp/changelog} -o /tmp/release_notes
cat /tmp/release_notes
if [[ ${PUSH_TO} =~ ^github$ ]]; then
  ${DIR}/publish_plugin_github.sh
else
  ${DIR}/publish_plugin_osgeo.py -u "${OSGEO_USERNAME}" -w "${OSGEO_PASSWORD}" -r "${TRAVIS_TAG}" ${ZIPFILENAME} -c /tmp/release_notes
fi
