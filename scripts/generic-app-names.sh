#!/bin/bash

# Source: https://askubuntu.com/a/564773

targetdir=~/.local/share/applications/

for i in $(grep -l "^GenericName=" "$targetdir"/*.desktop); do
  echo Hit on $i
  tmphit=$(sed -n 's/^GenericName=//p' "$i")
  echo Generic name is:"$tmphit"
  sed -iBAK "0,/^Name=/s/^Name=.*/Name=$tmphit/g" "$i" || echo "SED FAILED!!!!"
done
