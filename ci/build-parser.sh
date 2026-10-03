#!/usr/bin/env bash
# Make sure OMParser has a parser library for the running Julia version: if
# OMParser publishes one (Latest-<os>-julia-X.Y), Pkg.build downloads it later;
# otherwise build it here from OMParser.jl/lib/parser (needs autoconf, make, a
# C compiler, Java for ANTLR and `julia` on PATH) and install it the way a
# download is installed, in lib/julia-X.Y (deps/build.jl then uses it).
# With PACKAGE=OMParser (OMParser under test) always build: the change may be
# in the parser itself, which a released library would not contain.
set -euo pipefail
cd "$(dirname "$0")/../OMParser.jl"
mm=$(julia --startup-file=no -e 'print(VERSION.major, ".", VERSION.minor)')
case "$(uname -s)" in
  Linux) os=ubuntu-latest ;;
  Darwin) os=macos-latest ;;
  *) os=windows-latest ;;
esac
url="https://github.com/OpenModelica/OMParser.jl/releases/download/Latest-$os-julia-$mm/parser-library-$os-julia-$mm.zip"
if [ "${PACKAGE:-}" != OMParser ] && curl -fsIL "$url" > /dev/null 2>&1; then
  echo "OMParser: release library for Julia $mm exists; Pkg.build will download it"
  exit 0
fi
if [ -d "lib/julia-$mm" ]; then
  echo "OMParser: lib/julia-$mm already present"
  exit 0
fi
if [ "${PACKAGE:-}" = OMParser ]; then
  echo "OMParser is under test: building its parser library from source"
else
  echo "OMParser: no release library for Julia $mm ($url); building from source"
fi
(cd lib/parser && autoconf && ./configure && make)
mkdir -p "lib/julia-$mm"
cp -R lib/build/lib/. "lib/julia-$mm/"
# The loader falls back to any unversioned library under lib/, so remove the
# build tree's copies: they are linked against this Julia version only.
git clean -xdfq lib/parser lib/build lib/3rdParty
find "lib/julia-$mm" -name 'libomparse-julia*'
