#!/bin/bash

function start_postgres { # 1 - optional container name
  local NAME="${1:-postgres}"
  docker run --name $NAME -e POSTGRES_PASSWORD=postgres --network host -d postgres
}

function kill_postgres { # 1 - optional container name
  local NAME="${1:-postgres}"
  docker stop $NAME
  docker rm $NAME
}
