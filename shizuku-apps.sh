#!/system/bin/sh
# shizuku-apps.sh — MASTER SCRIPT
# Fetches + silently installs the hand-picked apps chosen from awesome-shizuku.
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
# skipped, so it's safe to re-run. Comment out a line at the bottom
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
    apks=$(get "https://api.github.com/repos/$3/releases/latest" \
        | tr ',' '\n' | grep browser_download_url | grep -o 'https://[^"]*\.apk')
    # prefer a plain arm64 build over fdroid-flavored or other-ABI variants
    url=$(echo "$apks" | grep -v -E 'fdroid|x86|armeabi' | grep -m1 arm64)
    [ -z "$url" ] && url=$(echo "$apks" | grep -m1 -E 'arm64|universal')
    [ -z "$url" ] && url=$(echo "$apks" | head -n1)
    if [ -z "$url" ]; then echo "!! $1: could not resolve GitHub release"; return 1; fi
    install_apk "$1" "$2" "$url"
}

# ---- the apps --------------------------------------------------------------

github "ObtainX"      dev.bikram.obtainx                  bikram-agarwal/ObtainX          # Obtainium fork, Material 3 UI — auto-updates sideloaded apps
fdroid "Canta"        io.github.samolego.canta                                            # debloat: uninstall system apps without root
fdroid "LogFox"       com.f0x1d.logfox                                                    # FOSS logcat reader with background crash recording
github "AntiSplit-M"  com.abdurazaaqmohammed.AntiSplit    AbdurazaaqMohammed/AntiSplit-M  # merge split APKs (APKS/XAPK/APKM) into one installable APK
github "WiFi Password Manager" io.github.wifi_password_manager Khh-vu/wifi-password-manager # view every saved Wi-Fi password, no root
izzy   "LinkSheet"    fe.linksheet                                                        # restore the 'open link with...' app chooser, per-domain rules
izzy   "Amarok-Hider" deltazero.amarok.foss                                               # one-tap hide private apps and files
github "ShizuWall"    com.arslan.shizuwall                AhmetCanArslan/ShizuWall        # per-app firewall, no VPN slot — plays nice with Tailscale

echo
echo "Done. Grant each app Shizuku permission when it asks on first launch."
echo "Tip: add these repos to ObtainX so everything auto-updates from now on."
