#!/bin/bash
cd /home/container

# CS:GO ships an old bundled bin/libgcc_s.so.1 that lacks GCC_7.0.0 symbols.
# Remove it so the system lib32gcc-s1 version is used instead.
rm -f /home/container/bin/libgcc_s.so.1

# Replace Pelican {{VAR}} placeholders with shell ${VAR} equivalents, then eval-expand them
MODIFIED_STARTUP=$(eval echo "$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')")

echo "/home/container$ ${MODIFIED_STARTUP}"
eval "${MODIFIED_STARTUP}"
