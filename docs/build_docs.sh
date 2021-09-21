#!/bin/bash
set -euo pipefail

# Change to root directory of repo
DIRNAME=$(cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
cd "${DIRNAME}/.."

# Set up virtual environment
pip3 install --upgrade pip setuptools wheel virtualenv
if [ ! -d venv ]; then
  rm -f venv
  virtualenv venv
fi
source venv/bin/activate

# Clean up build directory and install Sphinx requirements
pip3 install -r "${DIRNAME}/requirements.txt"
sphinx-build -M clean "${DIRNAME}/source" "${DIRNAME}/build"

# Install all previous released versions of Merlion/ts_datasets
# and use them to build the appropriate API docs.
# Uninstall after we're done with each one.
versions=()
for version in $(git tag --list 'v[0-9]*'); do
    versions+=("$version")
    git checkout "tags/${version}"
    export current_version=${version}
    pip3 install ".[plot]"
    pip3 install ts_datasets/
    sphinx-build -b html "${DIRNAME}/source" "${DIRNAME}/build/html/${current_version}"
    rm -rf "${DIRNAME}/build/html/${current_version}/.doctrees"
    pip3 uninstall -y sfdc-merlion
    pip3 uninstall -y ts_datasets
done

# Install main branch version & build API docs
git checkout main
export current_version="latest"
pip3 install ".[plot]"
pip3 install ts_datasets/
sphinx-build -b html "${DIRNAME}/source" "${DIRNAME}/build/html/${current_version}"
rm -rf "${DIRNAME}/build/html/${current_version}/.doctrees"

# Determine the latest stable version if there is one
if (( ${#versions[@]} > 0 )); then
  stable_hash=$(git rev-list --tags --max-count=1)
  stable_version=$(git describe --tags "$stable_hash")
  export stable_version
else
  export stable_version="latest"
fi

# Create dummy HTML's for the stable version in the base directory
while read -r filename; do
    filename=$(echo "$filename" | sed "s/\.\///")
    n_sub=$(echo "$filename" | (grep -o "/" || true) | wc -l)
    prefix=""
    for (( i=0; i<n_sub; i++ )); do
        prefix+="../"
    done
    url="${prefix}${stable_version}/$filename"
    mkdir -p "${DIRNAME}/build/html/$(dirname "$filename")"
    cat > "${DIRNAME}/build/html/$filename" <<EOF
<!DOCTYPE html>
<html>
   <head>
      <title>Merlion Documentation</title>
      <meta http-equiv = "refresh" content="0; url='$url'" />
   </head>
   <body>
      <p>Please wait while you're redirected to our <a href="$url">documentation</a>.</p>
   </body>
</html>
EOF
done < <(cd "${DIRNAME}/build/html/$stable_version" && find . -name "*.html")

# Add README
cat > "${DIRNAME}/build/html/README.md" <<EOF
# GitHub Pages

The contents of this branch are automatically generated by GitHub Actions. This branch is used by GitHub Pages to
populate the API documentation [here](https://salesforce.github.io/Merlion).

EOF
