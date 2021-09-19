#!/usr/bin/env bash
set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

# Make sure to use project tooling
PATH="$(pwd)/tmp/bin:${PATH}"
TESTFILE="$(pwd)/tmp/test.jsonnet"
mkdir -p "$(pwd)/tmp"

for i in examples/jsonnet-snippets/*.jsonnet; do
    [ -f "$i" ] || break
    echo "Testing: ${i}"
    echo ""
    fileContent=$(<"$i")
    snippet="local kp = $fileContent;

$(<examples/jsonnet-build-snippet/build-snippet.jsonnet)"
    echo "${snippet}" > "${TESTFILE}"
    echo "\`\`\`"
    echo "${snippet}"
    echo "\`\`\`"
    echo ""
    jsonnet -J vendor "${TESTFILE}" > /dev/null
    rm -rf "${TESTFILE}"
done

for i in examples/*.jsonnet; do
    [ -f "$i" ] || break
    echo "Testing: ${i}"
    echo ""
    echo "\`\`\`"
    cat "${i}"
    echo "\`\`\`"
    echo ""
    jsonnet -J vendor "${i}" > /dev/null
done
