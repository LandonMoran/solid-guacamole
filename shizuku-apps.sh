#!/system/bin/sh
# shizuku-apps.sh — MASTER SCRIPT
# Fetches + silently installs the hand-picked app collection.
# Also supports removing everything it manages:  sh shizuku-apps.sh uninstall
#
# ============================ HOW TO RUN =====================================
# IMPORTANT: stock Pixels ship NO curl/wget in the adb/Shizuku shell, so the
# recommended way to run this is Termux + rish (both one-time setups):
#
#   RECOMMENDED — Termux + rish:
#     1. Install Termux (you have F-Droid; it's on there).
#     2. In the Shizuku app: "Use terminal apps" -> export rish to Termux.
#     3. In Termux:  pkg install curl
#     4. In Termux:  sh /sdcard/Download/shizuku-apps.sh
#        (grant Termux storage access first: termux-setup-storage)
#
#   ALTERNATIVE A — aShell / adb shell, with a one-time static curl:
#     From a PC: adb push curl /data/local/tmp/curl && adb shell chmod 755 /data/local/tmp/curl
#     (get a static arm64 curl from https://github.com/stunnel/static-curl)
#     Then in aShell:  sh /sdcard/Download/shizuku-apps.sh
#
#   ALTERNATIVE B — aShell / adb shell, no network tool at all:
#     Pre-download the APKs with your browser into /sdcard/Download/shizuku-apks/
#     then run the script; it will install everything it finds there.
#
#   UNINSTALL everything this script manages:
#     sh /sdcard/Download/shizuku-apps.sh uninstall
#
# Already-installed apps are skipped, so re-running is always safe.
# NOTE for aShell: type the command; don't paste the script body (aShell
# strips newlines from pasted text). Keep the app in the foreground while
# it runs.
# =============================================================================

ACTION="${1:-install}"

# ---- figure out how to talk to pm (direct shell vs rish from Termux) --------

if pm path android >/dev/null 2>&1; then
    PM_MODE=direct
    WORK=/data/local/tmp/shizuku-apps
elif command -v rish >/dev/null 2>&1 && rish -c "pm path android" >/dev/null 2>&1; then
    PM_MODE=rish
    WORK=/sdcard/Download/shizuku-apks
else
    echo "!! Can't reach pm. Run this in aShell/adb shell, or in Termux with rish set up"
    echo "   (Shizuku app -> 'Use terminal apps' -> export rish)."
    exit 1
fi
mkdir -p "$WORK" 2>/dev/null || { echo "!! Can't create $WORK (in Termux, run termux-setup-storage first)"; exit 1; }

pm_has()       { [ "$PM_MODE" = direct ] && pm path "$1" >/dev/null 2>&1 || { [ "$PM_MODE" = rish ] && rish -c "pm path $1" >/dev/null 2>&1; }; }
pm_install()   { # <apk-path>
    if [ "$PM_MODE" = direct ]; then
        pm install -r "$1" >/dev/null 2>&1 && return 0
        size=$(stat -c%s "$1" 2>/dev/null)
        [ -n "$size" ] && cat "$1" | pm install -r -S "$size" >/dev/null 2>&1
    else # rish: uid 2000 can read /sdcard; stage into /data/local/tmp for installd
        rish -c "cp '$1' /data/local/tmp/.stage.apk && pm install -r /data/local/tmp/.stage.apk >/dev/null 2>&1; rc=\$?; rm -f /data/local/tmp/.stage.apk; exit \$rc"
    fi
}
pm_uninstall() { # <package>
    if [ "$PM_MODE" = direct ]; then pm uninstall --user 0 "$1" >/dev/null 2>&1
    else rish -c "pm uninstall --user 0 $1" >/dev/null 2>&1; fi
}

# ---- downloader detection ----------------------------------------------------

DLTOOL=""
command -v curl >/dev/null 2>&1 && DLTOOL=curl
[ -z "$DLTOOL" ] && command -v wget >/dev/null 2>&1 && DLTOOL=wget
[ -z "$DLTOOL" ] && [ -x /data/local/tmp/curl ] && DLTOOL=/data/local/tmp/curl

dl()  { # dl <url> <outfile>
    case "$DLTOOL" in
        wget) wget -qO "$2" "$1" ;;
        *)    "$DLTOOL" -fL --retry 3 --progress-bar -o "$2" "$1" ;;
    esac
}
get() { # get <url> -> stdout
    case "$DLTOOL" in
        wget) wget -qO- "$1" ;;
        *)    "$DLTOOL" -fsL --compressed "$1" 2>/dev/null || "$DLTOOL" -fsL "$1" ;;
    esac
}

# ---- installers ---------------------------------------------------------------

install_url() { # <name> <package> <url>
    echo "== $1: downloading..."
    apk="$WORK/$2.apk"
    if ! dl "$3" "$apk"; then echo "!! $1: download failed ($3)"; return 1; fi
    if pm_install "$apk"; then echo "== $1: installed OK"; else echo "!! $1: pm install failed"; fi
    rm -f "$apk"
}

# version-code field is unquoted on f-droid.org, quoted on izzysoft — handle both
vercode() { grep -o '"suggestedVersionCode": *"\{0,1\}[0-9]*' | grep -o '[0-9]*$'; }

src_fdroid() { # <name> <package>
    vc=$(get "https://f-droid.org/api/v1/packages/$2" | vercode)
    [ -z "$vc" ] && { echo "!! $1: could not resolve F-Droid version"; return 1; }
    install_url "$1" "$2" "https://f-droid.org/repo/${2}_${vc}.apk"
}
src_izzy() { # <name> <package>
    vc=$(get "https://apt.izzysoft.de/fdroid/api/v1/packages/$2" | vercode)
    [ -z "$vc" ] && { echo "!! $1: could not resolve IzzyOnDroid version"; return 1; }
    install_url "$1" "$2" "https://apt.izzysoft.de/fdroid/repo/${2}_${vc}.apk"
}
src_github() { # <name> <package> <owner/repo>
    apks=$(get "https://api.github.com/repos/$3/releases/latest" \
        | tr ',' '\n' | grep browser_download_url | grep -o 'https://[^"]*\.apk')
    url=$(echo "$apks" | grep -v -E 'fdroid|x86|armeabi' | grep -m1 arm64)  # prefer plain arm64
    [ -z "$url" ] && url=$(echo "$apks" | grep -m1 -E 'arm64|universal')
    [ -z "$url" ] && url=$(echo "$apks" | head -n1)
    [ -z "$url" ] && { echo "!! $1: could not resolve GitHub release"; return 1; }
    install_url "$1" "$2" "$url"
}
src_mixp() { # <name> <package>  (mixplorer.com hosts versioned APKs on one page)
    f=$(get "https://mixplorer.com/beta/" | grep -ao 'href="MiXplorer_[^"]*\.apk"' | cut -d'"' -f2 | head -1)
    [ -z "$f" ] && { echo "!! $1: could not resolve mixplorer.com download"; return 1; }
    install_url "$1" "$2" "https://mixplorer.com/beta/$f"
}

# ---- the app roster -----------------------------------------------------------

app() { # app <src> <name> <package> [repo]
    if [ "$ACTION" = "uninstall" ]; then
        if pm_has "$3"; then
            pm_uninstall "$3" && echo "== $2: uninstalled" || echo "!! $2: uninstall failed"
        else
            echo "== $2: not installed"
        fi
        return
    fi
    if pm_has "$3"; then echo "== $2: already installed, skipping"; return; fi
    "src_$1" "$2" "$3" "$4"
}

run_roster() {
    app github "ObtainX"      dev.bikram.obtainx                 bikram-agarwal/ObtainX          # app updater for sideloads, Material 3 Expressive
    app fdroid "Canta"        io.github.samolego.canta                                           # uninstall system apps / debloat, no root
    app fdroid "LogFox"       com.f0x1d.logfox                                                   # logcat reader + crash recording
    app github "AntiSplit-M"  com.abdurazaaqmohammed.AntiSplit   AbdurazaaqMohammed/AntiSplit-M  # merge split APKs into one installable APK
    app github "WiFi Password Manager" io.github.wifi_password_manager Khh-vu/wifi-password-manager # view saved Wi-Fi passwords
    app izzy   "LinkSheet"    fe.linksheet                                                       # restore the open-with link chooser
    app izzy   "Amarok-Hider" deltazero.amarok.foss                                              # one-tap hide private apps/files
    app github "ShizuWall"    com.arslan.shizuwall               AhmetCanArslan/ShizuWall        # per-app firewall, no VPN slot (Tailscale-safe)
    app github "essentials"   com.sameerasw.essentials           sameerasw/essentials            # sameerasw's Pixel tools/mods grab-bag
    app github "Seal Plus"    com.maheshtechnicals.sealplus      MaheshTechnicals/Sealplus       # yt-dlp downloader, gradient UI fork
    app fdroid "YTDLnis"      com.deniscerri.ytdl                                                # yt-dlp download manager: queues, playlists, cookies
    app github "XStreaming"   com.dev.xstreaming                 Geocld/XStreaming               # FOSS Xbox remote play / xCloud power client
    app fdroid "PermissionManagerX" com.mirfatif.permissionmanagerx                              # FOSS App Ops control: clipboard, bg-start, wakelocks
    app mixp   "MiXplorer"    com.mixplorer                                                      # the legendary power-user file manager
}

# ---- go -----------------------------------------------------------------------

if [ "$ACTION" = "uninstall" ]; then
    echo "Removing all apps managed by this script..."
    run_roster
    echo; echo "Done."
    exit 0
fi

if [ -z "$DLTOOL" ]; then
    staged=$(ls "$WORK"/*.apk 2>/dev/null | wc -l)
    if [ "$staged" -gt 0 ]; then
        echo "No curl/wget here, but found $staged staged APK(s) in $WORK — installing those."
        for apk in "$WORK"/*.apk; do
            if pm_install "$apk"; then echo "== $(basename "$apk"): installed OK"; else echo "!! $(basename "$apk"): install failed"; fi
        done
        exit 0
    fi
    echo "!! No curl or wget available in this shell, and no staged APKs in $WORK."
    echo "   Fix one of these ways (see header of this script for details):"
    echo "     1. Run from Termux with rish + curl (recommended)"
    echo "     2. adb push a static curl to /data/local/tmp/curl (one-time)"
    echo "     3. Pre-download the APKs into $WORK and re-run"
    exit 1
fi

run_roster
echo
echo "Done. Grant each app Shizuku permission when it asks on first launch."
echo "Tip: add these to ObtainX so everything auto-updates from now on."
