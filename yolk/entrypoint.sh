#!/bin/bash
cd /home/container

# Replace Pelican {{VAR}} placeholders with shell ${VAR} equivalents, then eval-expand them
MODIFIED_STARTUP=$(eval echo "$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')")

echo "/home/container$ ${MODIFIED_STARTUP}"
eval "${MODIFIED_STARTUP}"
