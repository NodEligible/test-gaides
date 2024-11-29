#!/bin/bash

function get_status() {
    docker exec -t shardeum-dashboard operator-cli status 2>/dev/null | grep "state" | awk '{ print $2 }'
}

cd "$HOME" || exit
source .profile

while true; do
    printf "Check shardeum node status...\n"
    NODE_STATUS=$(get_status)

    if [[ -z "${NODE_STATUS}" ]]; then
        printf "Error: Unable to retrieve node status.\n"
        sleep 1m
        continue
    fi

    printf "Current status: ${NODE_STATUS}\n"
    if [[ "${NODE_STATUS}" == "stopped" ]]; then
        printf "Node is stopped. Starting shardeum node and waiting for 5 minutes...\n"
        docker exec -t shardeum-dashboard operator-cli start 2>/dev/null
        sleep 5m
    else
        date=$(date +"%H:%M:%S")
        printf "Node is running. Last Update: ${date}\n"
        printf "Sleeping for 15 minutes...\n"
        sleep 15m
    fi
done
