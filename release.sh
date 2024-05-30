#!/bin/bash
#
# Build a release container, generate a release tarball and tag a release.
#

name="mailserver"
container="ghcr.io/t-lo/${name}"

set -euo pipefail

script_dir="$(dirname "$0")"

function yell() {
    echo
    echo "#############  " "${@}" "  ##############"
    echo
}
# --

if [ -z "${1:-}" ] ; then
    echo "Usage: $0 'release-version'"
    exit 1
fi

version="$1"
release_name="${name}-${version}"

# Sanity

if ! git diff --exit-code; then
    yell "ERROR: Local changes detected (see diff above). Commit and push before creating a release."
    exit 1
fi

if ! git diff --staged --exit-code; then
    yell "ERROR: Staged changes detected (see diff above). Commit and push before creating a release."
    exit 1
fi

untracked="$(git ls-files --other --exclude-standard --directory 2>&1)"

if [ -n "${untracked}" ] ; then
    echo
    git ls-files --other --exclude-standard --directory 2>&1
    yell "ERROR: untracked files detected (see above). Please commit and push or remove before creating a release."
    exit 1
fi

yell "Building the container image"
docker build --pull -t "${container}:${version}" .
docker tag "${container}:${version}" "${container}:latest"

yell "Querying version information"
./package_versions.sh "${container}:${version}" release_package_versions.list | tee PACKAGE_VERSIONS

yell "Creating the release tarball"
echo "${version}" >VERSION
tar czvf "${release_name}.tgz" -T release-files.txt

yell "Creating the release tag"
git tag "${release_name}"

yell "Done."
echo "---------------------------------------"
echo "Now run:"
echo "   docker push ${container}:${version}"
echo "   docker push ${container}:latest"
echo "   git push origin"
echo "   git push origin ${release_name}"
echo
echo "Then go to"
echo "   https://github.com/t-lo/mailserver/releases/new"
echo "to create a new release, and attach ${release_name}.tgz"
echo
echo "Release version information"
echo "---------------------------"
cat PACKAGE_VERSIONS
