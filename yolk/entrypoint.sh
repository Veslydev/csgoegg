#!/bin/bash
cd /home/container

# CS:GO ships an old bundled bin/libgcc_s.so.1 that lacks GCC_7.0.0 symbols.
# Remove it so the system lib32gcc-s1 version is used instead.
rm -f /home/container/bin/libgcc_s.so.1

# srcds needs .steam/sdk32/steamclient.so — create the symlink if not present.
mkdir -p /home/container/.steam/sdk32
if [ ! -f /home/container/.steam/sdk32/steamclient.so ]; then
    ln -sf /home/container/linux32/steamclient.so /home/container/.steam/sdk32/steamclient.so
fi

# srcds_run sets SDR_LISTEN_PORT internally. Without SDR_CERT/SDR_PRIVATE_KEY this
# forces SDR relay mode and breaks Steam authentication in containers. Unset it.
unset SDR_LISTEN_PORT

# Replace Pelican {{VAR}} placeholders with shell ${VAR} equivalents, then eval-expand them
MODIFIED_STARTUP=$(eval echo "$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')")

echo "/home/container$ ${MODIFIED_STARTUP}"
eval "${MODIFIED_STARTUP}"
