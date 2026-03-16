#!/usr/bin/echo source this script
COMPOSE_FILE="docker-compose+docker-compose.${GOCLAW_MODULES//+/+docker-compose.}"
export COMPOSE_FILE="${COMPOSE_FILE//+/.yml:}.yml"

