#!/bin/bash

function start_postgres {
  docker run --name postgres -e POSTGRES_PASSWORD=postgres --network host -d postgres
}

function kill_postgres {
  docker stop postgres
  docker rm postgres
}
