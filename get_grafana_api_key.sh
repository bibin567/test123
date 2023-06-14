#!/bin/bash

# Fetch the Grafana API key using a command-line tool or API endpoint
API_KEY=$(your_command_to_retrieve_api_key)

# Output the API key as JSON
echo "{\"api_key\": \"$API_KEY\"}"
