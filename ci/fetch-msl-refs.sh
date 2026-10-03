#!/usr/bin/env bash
# Download the MSL reference results that OM.jl's tests compare against
# (validateMSLModel in test/), not the whole 1.3 GB set, into
# OMLibraryTesting.jl/reference via its download_refs.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
names=()
while read -r n; do names+=("$n"); done < <(
  grep -rh -A2 'validateMSLModel(' test |
    grep -oE '"[A-Z][A-Za-z0-9]*(_[A-Za-z0-9]+)+"' | tr -d '"' | sort -u)
echo "MSL reference results used by the tests: ${names[*]}"
cd OMLibraryTesting.jl/reference
# An older download_refs.sh ignores the names and fetches all 1.3 GB.
if ! grep -q 'SHORT_NAME\.\.\.' download_refs.sh; then
  echo "::error::OMLibraryTesting's download_refs.sh cannot fetch single models (needs 5c77ef9 or later)"
  exit 1
fi
bash download_refs.sh "${names[@]}"
