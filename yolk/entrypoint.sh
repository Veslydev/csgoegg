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

# ── Fix SourceMod MySQL library discovery ─────────────────────────────────────
# SourceMod's dbi.mysql.ext.so needs libmysqlclient.so in its library path.
# Add system i386 library path so it finds the MariaDB compat libraries.
export LD_LIBRARY_PATH="/usr/lib/i386-linux-gnu:${LD_LIBRARY_PATH}"

# ── Disable known-broken plugins ─────────────────────────────────────────────
# These plugins crash on load with missing dependencies. Move them to disabled/
# to stop the error spam. Users can re-enable after fixing the dependencies.
SM_PLUGINS="/home/container/csgo/addons/sourcemod/plugins"
SM_DISABLED="${SM_PLUGINS}/disabled"
mkdir -p "${SM_DISABLED}"

# teamsmanagementcommands.smx — requires a dependency plugin that provides
# the "RequestTeamsManagement" native. Fails every boot without it.
if [ -f "${SM_PLUGINS}/teamsmanagementcommands.smx" ]; then
    mv "${SM_PLUGINS}/teamsmanagementcommands.smx" "${SM_DISABLED}/" 2>/dev/null
fi

# ── Fix TeamBets translations ─────────────────────────────────────────────────
# TeamBets is missing its translation file, causing "Language phrase not found"
# errors every time a player chats or a timer fires.
TB_TRANS="/home/container/csgo/addons/sourcemod/translations/teambets.phrases.txt"
if [ -d /home/container/csgo/addons/sourcemod/translations ] && [ ! -f "$TB_TRANS" ]; then
    cat > "$TB_TRANS" << 'TBEOF'
"Phrases"
{
    "Advertise Bets"
    {
        "en"    "[TeamBets] Type !bet <team> <amount> to place a bet!"
        "tr"    "[TeamBets] Bahis yapmak için !bet <takım> <miktar> yazın!"
    }
    "Must Be Dead To Vote"
    {
        "en"    "[TeamBets] You must be dead to place a bet."
        "tr"    "[TeamBets] Bahis yapmak için ölü olmalısınız."
    }
    "Bet Made"
    {
        "en"    "[TeamBets] You bet $%s on %s."
        "tr"    "[TeamBets] %s takımına $%s bahis yaptınız."
    }
    "Invalid Team for Bet"
    {
        "en"    "[TeamBets] Invalid team. Use !bet ct or !bet t."
        "tr"    "[TeamBets] Geçersiz takım. !bet ct veya !bet t kullanın."
    }
}
TBEOF
fi

# ── Fix RankMe translations (missing "Wallbang" phrase) ───────────────────────
# Kento RankMe throws errors when a wallbang kill happens because the
# "Wallbang" phrase is missing from translations.
RANKME_TRANS="/home/container/csgo/addons/sourcemod/translations/kento_rankme.phrases.txt"
if [ -f "$RANKME_TRANS" ]; then
    if ! grep -q '"Wallbang"' "$RANKME_TRANS" 2>/dev/null; then
        # Insert before the closing brace of the Phrases block
        sed -i '/^}$/i\
    "Wallbang"\
    {\
        "en"    "Wallbang"\
        "tr"    "Duvar Arkası"\
    }' "$RANKME_TRANS"
    fi
fi

# ── Fix ServerAdvertisements config ───────────────────────────────────────────
# ServerAdvertisements fails on load if its config has messages without an "en"
# translation key. Check and fix message "1" if it exists without one.
SA_CFG="/home/container/csgo/addons/sourcemod/configs/serveradvertisements.cfg"
if [ -f "$SA_CFG" ]; then
    # If the file has a "1" message block but no "en" key inside it, add one
    if grep -q '"1"' "$SA_CFG" && ! grep -A5 '"1"' "$SA_CFG" | grep -q '"en"'; then
        sed -i '/"1"/,/}/{
            /}/i\
        "en"    "Welcome to the server!"
        }' "$SA_CFG" 2>/dev/null
    fi
fi

# ── Fix basecommands "Choose Config" phrase ───────────────────────────────────
# SourceMod's basecommands.smx throws an error if "Choose Config" phrase is
# missing. This can happen with mismatched SM versions or missing translation packs.
BC_TRANS="/home/container/csgo/addons/sourcemod/translations/basecommands.phrases.txt"
if [ -f "$BC_TRANS" ]; then
    if ! grep -q '"Choose Config"' "$BC_TRANS" 2>/dev/null; then
        sed -i '/^}$/i\
    "Choose Config"\
    {\
        "en"    "Choose Config"\
        "tr"    "Ayar Seç"\
    }' "$BC_TRANS"
    fi
fi

# ── Launch ────────────────────────────────────────────────────────────────────
# Replace Pelican {{VAR}} placeholders with shell ${VAR} equivalents, then eval-expand them
MODIFIED_STARTUP=$(eval echo "$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')")

echo "/home/container$ ${MODIFIED_STARTUP}"
eval "${MODIFIED_STARTUP}"
