#!/system/bin/sh
# shizuku-apps.sh — fetch + silently install a curated set of awesome-shizuku apps
#
# HOW TO RUN (pick one):
#   1. aShell (easiest): save this file to your Downloads folder, then run:
#        sh /sdcard/Download/shizuku-apps.sh
#   2. adb shell from a PC:
#        adb push shizuku-apps.sh /data/local/tmp/ && adb shell sh /data/local/tmp/shizuku-apps.sh
#   3. Termux with rish (Shizuku's shell wrapper):
#        rish -c "sh /sdcard/Download/shizuku-apps.sh"
#
# It runs as the `shell` user (what Shizuku gives you), so `pm install`
# works silently with no install prompts. Already-installed apps are
# skipped, so it's safe to re-run. Comment out any line at the bottom
# with a leading # to skip that app.

TMP=/data/local/tmp/shizuku-apps
mkdir -p "$TMP" || exit 1

# ---- helpers ---------------------------------------------------------------

dl() { # dl <url> <outfile>
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 --progress-bar -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$2" "$1"
    else
        echo "!! No curl or wget in this shell. Run this script through Termux+rish instead."
        exit 1
    fi
}

get() { # get <url> -> stdout
    if command -v curl >/dev/null 2>&1; then
        curl -fsL "$1"
    else
        wget -qO- "$1"
    fi
}

install_apk() { # install_apk <name> <package> <url>
    if pm path "$2" >/dev/null 2>&1; then
        echo "== $1: already installed, skipping"
        return 0
    fi
    echo "== $1: downloading..."
    apk="$TMP/$2.apk"
    if ! dl "$3" "$apk"; then
        echo "!! $1: download failed ($3)"
        return 1
    fi
    if pm install -r "$apk" >/dev/null 2>&1; then
        echo "== $1: installed OK"
    else
        # some builds need the apk streamed instead of read from disk
        size=$(stat -c%s "$apk" 2>/dev/null)
        if [ -n "$size" ] && cat "$apk" | pm install -r -S "$size" >/dev/null 2>&1; then
            echo "== $1: installed OK (streamed)"
        else
            echo "!! $1: pm install failed"
        fi
    fi
    rm -f "$apk"
}

# version-code field is unquoted on f-droid.org, quoted on izzysoft — handle both
vercode() { grep -o '"suggestedVersionCode": *"\{0,1\}[0-9]*' | grep -o '[0-9]*$'; }

fdroid() { # fdroid <name> <package>
    vc=$(get "https://f-droid.org/api/v1/packages/$2" | vercode)
    if [ -z "$vc" ]; then echo "!! $1: could not resolve F-Droid version"; return 1; fi
    install_apk "$1" "$2" "https://f-droid.org/repo/${2}_${vc}.apk"
}

izzy() { # izzy <name> <package>
    vc=$(get "https://apt.izzysoft.de/fdroid/api/v1/packages/$2" | vercode)
    if [ -z "$vc" ]; then echo "!! $1: could not resolve IzzyOnDroid version"; return 1; fi
    install_apk "$1" "$2" "https://apt.izzysoft.de/fdroid/repo/${2}_${vc}.apk"
}

github() { # github <name> <package> <owner/repo>
    url=$(get "https://api.github.com/repos/$3/releases/latest" \
        | tr ',' '\n' | grep browser_download_url | grep -o 'https://[^"]*\.apk' \
        | grep -i -m1 -E 'arm64|universal|release|\.apk')
    if [ -z "$url" ]; then echo "!! $1: could not resolve GitHub release"; return 1; fi
    install_apk "$1" "$2" "$url"
}

# ---- the apps --------------------------------------------------------------
# Everything below is open-source and listed on awesome-shizuku.

izzy   "Obtainium"            dev.imranr.obtainium                       # auto-update all your sideloaded/GitHub apps
fdroid "Canta"                io.github.samolego.canta                   # debloat: uninstall system apps without root
fdroid "Hail"                 com.aistra.hail                            # freeze/disable apps, in groups, one tap
fdroid "RootlessJamesDSP"     me.timschneeberger.rootlessjamesdsp        # system-wide EQ/DSP for your soundcore buds
fdroid "Better Internet Tiles" be.casperverswijvelt.unifiedinternetqs    # real one-tap Wi-Fi + mobile data QS tiles
fdroid "KeyMapper"            io.github.sds100.keymapper                 # remap buttons/gestures system-wide
fdroid "LogFox"               com.f0x1d.logfox                           # FOSS logcat reader with crash recording
fdroid "Tarnhelm"             cn.ac.lz233.tarnhelm                       # strip tracking junk from shared links
fdroid "ColorBlendr"          com.drdisagree.colorblendr                 # fine-tune Material You colors (Lawnchair-friendly)
izzy   "System UI Tuner"      com.zacharee1.systemuituner                # view/edit hidden Android settings
github "Smartspacer"          com.kieronquinn.app.smartspacer  KieronQuinn/Smartspacer  # supercharged At a Glance
github "DarQ"                 com.kieronquinn.app.darq         KieronQuinn/DarQ         # per-app force dark mode

# --- optional extras: remove the leading # to install -----------------------
#fdroid "Droid-ify"           com.looker.droidify                        # nicer Material F-Droid client
#fdroid "sing-box"            io.nekohasekai.sfa                         # proxy platform w/ per-app routing via Shizuku
#fdroid "AOD Toggle"          org.alberto97.aodtoggle                    # quick-settings tile for Always-on Display

echo
echo "Done. Remember: most of these need Shizuku permission granted"
echo "inside each app on first launch (they'll prompt you)."
