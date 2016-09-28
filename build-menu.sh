#!/bin/bash

#
# Copyright (c) 2016 Red Hat Inc and others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
# 
# Contributors:
#     Red Hat Inc - initial API and implementation
#

set -e

## global settings

KURA_BUILD_SELECTION=~/.kura.build.selection
IGNORE_PROFILES=(default)

## Test if we have the "dialog" command

hash dialog &>/dev/null || {
  echo >&2 "This script requires you to install 'dialog'. Exiting ..."
  echo >&2 "  on RHEL   run 'sudo yum install dialog'"
  echo >&2 "  on Fedora run 'sudo dnf install dialog'"
  echo >&2 "  on Ubuntu run 'sudo apt-get install dialog'"
  echo >&2 "  on Mac OS run 'brew install dialog'"
  exit 1
}

## detect all maven profiles of the "distrib" project

echo "Detecting profiles..."

PROFILES=$(mvn -N -f kura/distrib/pom.xml help:all-profiles  | grep "Profile Id"   | awk '{ print $3; }' | sort -u)

## clear out IGNOREs

declare -a p
for i in $PROFILES; do
  [[ " ${IGNORE_PROFILES[@]} " =~ " ${i} " ]] || p+=($i)
done
PROFILES="${p[@]}"

echo "Available profiles: $PROFILES"

## read previous selection

test -r "$KURA_BUILD_SELECTION" && readarray -t oldsel < "$KURA_BUILD_SELECTION"

## build command line

declare -a tags
for i in $PROFILES; do
  tags+=($i) # tag 
  tags+=("Profile: $i") # item

  state=$([[ " ${oldsel[@]} " =~ " ${i} " ]] && echo "on" || echo "off" )
  tags+=($state)
done

## execute dialog

set +e
exec 3>&1 
sel=$(dialog --checklist "Select Eclipse Kura build profiles" 20 70 18 "${tags[@]}" 2>&1 1>&3)
rc=$?
exec 3>&-
set -e

## test for abort

echo
test $rc -eq 0 || { echo "Selection aborted ..." ; exit 2; }

## store selection

echo "Storing as $KURA_BUILD_SELECTION ..."
echo $sel > "$KURA_BUILD_SELECTION"

## build target command

echo "Running profiles: $sel"

declare -a pl
for i in $PROFILES; do
 state=$([[ " ${sel[@]} " =~ " ${i} " ]] && echo "-P$i" || echo "-P!$i" )
 pl+=("$state")
done

echo "Arguments:" "${pl[@]}"
echo "All arguments:" "${pl[@]}" "$@"

## execute

./build-all.sh "${pl[@]}" "$@"