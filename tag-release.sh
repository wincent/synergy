#!/bin/sh -e
# Copyright 2007-present Greg Hurrell.

#
# Configuration
#

TAG_NAME=Synergy

#
# Functions
#

die()
{
  echo "fatal: $1"
  exit 1
}

#
# Main
#

test $# -eq 1 || die "expected 1 parameter (the version number), received $#"
VERSION=$1
PREFIX=$(git rev-parse --show-prefix)
test -z "$PREFIX" || die "not at top of working tree"

echo "Preview:"
echo "  git tag -s $VERSION -m \"$VERSION release\" in $(pwd)"

/bin/echo -n "Enter yes to continue: "
read CONFIRM
if [ "$CONFIRM" = "yes" ]; then
  git tag -s $VERSION -m "$VERSION release"
fi
