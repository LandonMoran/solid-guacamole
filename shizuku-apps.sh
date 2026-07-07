#!/system/bin/sh
# shizuku-apps.sh — MASTER SCRIPT (runtime-fetch, no zip)
# Downloads the latest build of each curated app and installs it silently.
#
# ===================== RECOMMENDED: aShell (accessible) ======================
# aShell is a normal, TalkBack-friendly app and runs as the shell user, so it
# can install directly. Stock Pixels just lack a downloader, so you supply one
# static `curl` once. Using your BROWSER (accessible), download these 3 files
# into your Downloads folder:
#
#   1) the script:
#      https://raw.githubusercontent.com/landonmoran/solid-guacamole/claude/suzuki-app-recommendations-frsmqx/shizuku-apps.sh
#   2) curl (static arm64 binary):
#      https://raw.githubusercontent.com/landonmoran/solid-guacamole/claude/suzuki-app-recommendations-frsmqx/shell-tools/curl
#   3) cacert.pem (HTTPS certificates):
#      https://raw.githubusercontent.com/landonmoran/solid-guacamole/claude/suzuki-app-recommendations-frsmqx/shell-tools/cacert.pem
#
# Then make sure Shizuku is running, open aShell, and run this ONE line:
#      sh /sdcard/Download/shizuku-apps.sh
#
# The script copies curl into an executable spot, then downloads + installs
# everything. Uninstall everything it manages with:
#      sh /sdcard/Download/shizuku-apps.sh uninstall
#
# Already-installed apps are skipped, so re-running is safe.
#
# ---- Optional: Termux + rish (only if you prefer it) ------------------------
# If you ever use Termux instead: pkg install curl; termux-setup-storage; set
# up rish from the Shizuku app; then `bash shizuku-apps.sh`. The script
# auto-detects rish. (Termux's terminal is poor with TalkBack, so aShell above
# is the better path for screen-reader use.)
# =============================================================================

ACTION="${1:-install}"

# ---- locate rish (PATH, home, or current dir) --------------------------------
RISH=""
for c in "rish" "$HOME/rish" "./rish"; do
    if command -v "$c" >/dev/null 2>&1 || [ -f "$c" ]; then
        if sh "$c" -c "echo ok" >/dev/null 2>&1; then RISH="sh $c"; break; fi
    fi
done

# ---- choose how we reach pm --------------------------------------------------
if pm path android >/dev/null 2>&1; then
    PM_MODE=direct;  WORK=/data/local/tmp/shizuku-apps
elif [ -n "$RISH" ] && $RISH -c "pm path android" >/dev/null 2>&1; then
    PM_MODE=rish;    WORK=/sdcard/Download/shizuku-apks
else
    echo "!! Can't reach 'pm'."
    echo "   - In Termux: finish the rish setup in the header (step 4) and make sure Shizuku is running."
    echo "   - Or run this inside aShell / adb shell."
    exit 1
fi
mkdir -p "$WORK" 2>/dev/null || { echo "!! Can't create $WORK (in Termux run: termux-setup-storage)"; exit 1; }
echo ">> mode: $PM_MODE"

pm_has() {
    if [ "$PM_MODE" = direct ]; then pm path "$1" >/dev/null 2>&1
    else $RISH -c "pm path $1" >/dev/null 2>&1; fi
}
pm_install() { # <apk-path>
    if [ "$PM_MODE" = direct ]; then
        pm install -r "$1" >/dev/null 2>&1 && return 0
        size=$(stat -c%s "$1" 2>/dev/null)
        [ -n "$size" ] && cat "$1" | pm install -r -S "$size" >/dev/null 2>&1
    else
        $RISH -c "cp '$1' /data/local/tmp/.stage.apk && pm install -r /data/local/tmp/.stage.apk >/dev/null 2>&1; rc=\$?; rm -f /data/local/tmp/.stage.apk; exit \$rc"
    fi
}
pm_uninstall() { # <package>
    if [ "$PM_MODE" = direct ]; then pm uninstall --user 0 "$1" >/dev/null 2>&1
    else $RISH -c "pm uninstall --user 0 $1" >/dev/null 2>&1; fi
}

# ---- downloader (system curl/wget, or a bootstrapped static curl) ------------
DLTOOL=""; DLCURL=""; CACERT=""
if command -v curl >/dev/null 2>&1; then
    DLTOOL=curl; DLCURL=curl
elif command -v wget >/dev/null 2>&1; then
    DLTOOL=wget
else
    # No system downloader (typical in aShell): bootstrap the static curl the
    # user placed in Downloads. /sdcard is noexec, so copy it somewhere runnable.
    if [ ! -x /data/local/tmp/curl ] && [ -f /sdcard/Download/curl ]; then
        cp /sdcard/Download/curl /data/local/tmp/curl 2>/dev/null && chmod 755 /data/local/tmp/curl 2>/dev/null
        [ -f /sdcard/Download/cacert.pem ] && cp /sdcard/Download/cacert.pem /data/local/tmp/cacert.pem 2>/dev/null
    fi
    if [ -x /data/local/tmp/curl ]; then
        DLTOOL=curl; DLCURL=/data/local/tmp/curl
        [ -f /data/local/tmp/cacert.pem ] && CACERT="--cacert /data/local/tmp/cacert.pem"
        echo ">> using bootstrapped curl (/data/local/tmp/curl)"
    fi
fi

dl()  { if [ "$DLTOOL" = wget ]; then wget -qO "$2" "$1"; else $DLCURL $CACERT -fL --retry 3 -o "$2" "$1"; fi; }
get() { if [ "$DLTOOL" = wget ]; then wget -qO- "$1"; else $DLCURL $CACERT -fsL "$1"; fi; }

install_url() { # <name> <package> <url>
    echo "== $1: downloading..."
    apk="$WORK/$2.apk"
    if ! dl "$3" "$apk"; then echo "!! $1: download failed"; return 1; fi
    if pm_install "$apk"; then echo "== $1: installed OK"; else echo "!! $1: install failed"; fi
    rm -f "$apk"
}

vercode() { grep -o '"suggestedVersionCode": *"\{0,1\}[0-9]*' | grep -o '[0-9]*$'; }

src_fdroid() { vc=$(get "https://f-droid.org/api/v1/packages/$2" | vercode)
    [ -z "$vc" ] && { echo "!! $1: no F-Droid version"; return 1; }
    install_url "$1" "$2" "https://f-droid.org/repo/${2}_${vc}.apk"; }
src_izzy() { vc=$(get "https://apt.izzysoft.de/fdroid/api/v1/packages/$2" | vercode)
    [ -z "$vc" ] && { echo "!! $1: no IzzyOnDroid version"; return 1; }
    install_url "$1" "$2" "https://apt.izzysoft.de/fdroid/repo/${2}_${vc}.apk"; }
src_github() { apks=$(get "https://api.github.com/repos/$3/releases/latest" \
        | tr ',' '\n' | grep browser_download_url | grep -o 'https://[^"]*\.apk')
    url=$(echo "$apks" | grep -v -E 'fdroid|x86|armeabi' | grep -m1 arm64)
    [ -z "$url" ] && url=$(echo "$apks" | grep -m1 -E 'arm64|universal')
    [ -z "$url" ] && url=$(echo "$apks" | head -n1)
    [ -z "$url" ] && { echo "!! $1: no GitHub release apk"; return 1; }
    install_url "$1" "$2" "$url"; }
src_mixp() { f=$(get "https://mixplorer.com/beta/" | grep -ao 'href="MiXplorer_[^"]*\.apk"' | cut -d'"' -f2 | head -1)
    [ -z "$f" ] && { echo "!! $1: no mixplorer build"; return 1; }
    install_url "$1" "$2" "https://mixplorer.com/beta/$f"; }

app() { # app <src> <name> <package> [repo]
    if [ "$ACTION" = uninstall ]; then
        if pm_has "$3"; then pm_uninstall "$3" && echo "== $2: uninstalled" || echo "!! $2: uninstall failed"
        else echo "== $2: not installed"; fi
        return
    fi
    if pm_has "$3"; then echo "== $2: already installed, skipping"; return; fi
    "src_$1" "$2" "$3" "$4"
}

roster() {
    app github "ObtainX"       dev.bikram.obtainx                 bikram-agarwal/ObtainX          # app updater, Material 3 Expressive UI
    app fdroid "Canta"         io.github.samolego.canta                                           # uninstall system apps / debloat
    app fdroid "LogFox"        com.f0x1d.logfox                                                   # logcat reader + crash recording
    app github "AntiSplit-M"   com.abdurazaaqmohammed.AntiSplit   AbdurazaaqMohammed/AntiSplit-M  # merge split APKs into one
    app github "WiFi Passwords" io.github.wifi_password_manager    Khh-vu/wifi-password-manager    # view saved Wi-Fi passwords
    app izzy   "LinkSheet"     fe.linksheet                                                       # restore the open-with link chooser
    app izzy   "Amarok-Hider"  deltazero.amarok.foss                                              # hide private apps/files
    app github "de1984"        io.github.dorumrr.de1984           dorumrr/de1984                  # firewall + package manager, no VPN slot
    app github "essentials"    com.sameerasw.essentials           sameerasw/essentials            # Pixel tools/mods grab-bag
    app github "Seal Plus"     com.maheshtechnicals.sealplus      MaheshTechnicals/Sealplus       # yt-dlp downloader, gradient UI
    app fdroid "YTDLnis"       com.deniscerri.ytdl                                                # yt-dlp download manager
    app github "XStreaming"    com.dev.xstreaming                 Geocld/XStreaming               # Xbox remote play / xCloud client
    app fdroid "Permission Manager X" com.mirfatif.permissionmanagerx                             # AppOps control (clipboard, bg-start)
    app mixp   "MiXplorer"     com.mixplorer                                                      # power-user file manager
    app fdroid "Inure"         app.simple.inure                                                   # app manager with extra features
    app fdroid "Neo Store"     com.machiav3lli.fdroid                                             # F-Droid client w/ extra features
    app github "ShizuTools"    com.legendsayantan.adbtools        legendsayantan/ShizuTools       # per-app volume, force PiP, intent shell
}

# apps to remove after install (replaced by something above)
POST_UNINSTALL="org.fdroid.fdroid"   # official F-Droid -> replaced by Neo Store

# ---- run ---------------------------------------------------------------------
if [ "$ACTION" = uninstall ]; then
    echo "Removing all apps managed by this script..."; roster; echo; echo "Done."; exit 0
fi

if [ -z "$DLTOOL" ]; then
    staged=$(ls "$WORK"/*.apk 2>/dev/null | wc -l)
    if [ "$staged" -gt 0 ]; then
        echo "No curl/wget, but found $staged staged APK(s) in $WORK — installing those."
        for apk in "$WORK"/*.apk; do
            pm_install "$apk" && echo "== $(basename "$apk"): OK" || echo "!! $(basename "$apk"): failed"
        done
        exit 0
    fi
    echo "!! No downloader available. Put curl + cacert.pem in your Downloads folder"
    echo "   (see the header of this script for the exact download links), then re-run."
    echo "   Or pre-download the APKs into $WORK and re-run to install them offline."
    exit 1
fi

roster

# replace-and-remove step
for p in $POST_UNINSTALL; do
    if pm_has "$p"; then pm_uninstall "$p" && echo "== removed replaced app: $p"; fi
done

echo
echo "Done. Open each app once and grant it Shizuku permission when asked."
echo "Tip: add all these to ObtainX so they auto-update from now on."
