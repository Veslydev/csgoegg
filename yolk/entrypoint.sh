#!/bin/bash
cd /home/container

# ── Fix bundled libgcc_s ──────────────────────────────────────────────────────
# CS:GO ships an old bin/libgcc_s.so.1 that lacks GCC_7.0.0 symbols.
# Remove it so the system lib32gcc-s1 version is used instead.
rm -f /home/container/bin/libgcc_s.so.1

# ── Fix steamclient.so ────────────────────────────────────────────────────────
# srcds needs .steam/sdk32/steamclient.so — create the symlink if not present.
mkdir -p /home/container/.steam/sdk32
if [ ! -f /home/container/.steam/sdk32/steamclient.so ]; then
    # Try SteamCMD's copy first, then fall back to the game's copy
    if [ -f /home/container/steamcmd/linux32/steamclient.so ]; then
        ln -sf /home/container/steamcmd/linux32/steamclient.so /home/container/.steam/sdk32/steamclient.so
    elif [ -f /home/container/linux32/steamclient.so ]; then
        ln -sf /home/container/linux32/steamclient.so /home/container/.steam/sdk32/steamclient.so
    fi
fi

# ── Patch steam.inf App ID (740 → 4465480) ───────────────────────────────────
# Server files are from App 740 but players connect via App 4465480.
# Patch on every boot in case a SteamCMD update resets it.
if [ -f /home/container/csgo/steam.inf ]; then
    sed -i 's/appID=.*/appID=4465480/' /home/container/csgo/steam.inf
fi

# ── Fix MetaMod VDF (force 32-bit path for CS:GO) ────────────────────────────
# Newer MetaMod 1.12 builds ship both 32-bit and 64-bit binaries. The default
# VDF points to linux64/server which is the CS2 build. CS:GO's srcds is 32-bit
# and needs addons/metamod/bin/server instead.
if [ -d /home/container/csgo/addons/metamod ]; then
    cat > /home/container/csgo/addons/metamod.vdf << 'VDFEOF'
"Plugin"
{
    "file"  "addons/metamod/bin/server"
}
VDFEOF
    # Remove 64-bit binaries so srcds never tries to dlopen them
    rm -rf /home/container/csgo/addons/metamod/bin/linux64
fi

# ── Fix SDR relay mode ────────────────────────────────────────────────────────
# srcds_run sets SDR_LISTEN_PORT internally. Without SDR_CERT/SDR_PRIVATE_KEY
# this forces SDR relay mode and breaks Steam authentication in containers.
# Export empty value AND patch srcds_run to comment out its internal reassignment.
export SDR_LISTEN_PORT=
export SDR_CERT=
export SDR_PRIVATE_KEY=
if [ -f /home/container/srcds_run ]; then
    sed -i 's/^\(\s*export SDR_LISTEN_PORT=\)/#\1/' /home/container/srcds_run
fi

# ── Fix BotProfile.db 'Rank' attribute ────────────────────────────────────
# CS:GO's engine doesn't recognise the 'Rank' attribute, causing harmless but
# noisy parse errors. Strip those lines so the console stays clean.
if [ -f /home/container/csgo/botprofile.db ]; then
    sed -i '/^\s*Rank\b/Id' /home/container/csgo/botprofile.db
fi

# ── Launch ────────────────────────────────────────────────────────────────────
# Replace Pelican {{VAR}} placeholders with shell ${VAR} equivalents, then eval-expand them
MODIFIED_STARTUP=$(eval echo "$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')")

echo "/home/container$ ${MODIFIED_STARTUP}"
eval "${MODIFIED_STARTUP}"
