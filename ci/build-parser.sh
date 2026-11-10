#!/usr/bin/env bash
# OMParser has no native library since 1.0: nothing to build. Until this branch
# is on master, the reusable workflow there (omjl-ci.yml, which every package's
# pull request uses) still runs this script from the OM.jl checkout; this
# branch's omjl-ci.yml does not. Delete it after the merge.
echo "OMParser is written in Julia since 1.0: no parser library to build"
