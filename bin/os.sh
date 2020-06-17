#!/usr/bin/env bash
UNAME=$( command -v uname)

case $( "${UNAME}" | tr '[:upper:]' '[:lower:]') in
  linux*)
    printf 'linux'
    ;;
  darwin*)
    printf 'darwin'
    ;;
  msys*|cygwin*|mingw*)
    # or possible 'bash on windows'
    printf 'windows'
    ;;
  nt|win*)
    printf 'windows'
    ;;
  *)
    printf 'unknown'
    ;;
esac
