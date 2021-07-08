#!/bin/bash

IFS=', ' read -r -a PACKAGE_LISTS <<< "$1"

scope() {
  echo -e "[Installing]:"
  local PACKAGE_LISTS_FULL_PATH=()
  for FILE in "${PACKAGE_LISTS[@]}"; do
    local FULL_PATH="$DOTFILES_DIR/packages/archlinux/$FILE"
    PACKAGE_LISTS_FULL_PATH+=("$FULL_PATH")
    cat ${FULL_PATH}
  done

  local LISTS="${PACKAGE_LISTS[@]}"
  read -p "Install missing packages from $LISTS? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo pkgls -llll install -i ${PACKAGE_LISTS_FULL_PATH[@]}
  fi
}

scope
