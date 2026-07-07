#!/system/bin/sh
# shizuku-lite.sh — LIGHTWEIGHT installer. Reuses the curl already on your phone
# (from the one-time self-contained installer), so this file stays tiny.
#
# Needs /data/local/tmp/curl + cacert.pem to exist (they do after you ran the
# big installer once, and they persist across reboots/updates).
#
# Fetch + run it entirely from the shell (no browser) using dl.sh:
#     sh /sdcard/Download/dl.sh <this-file-url> /sdcard/Download/shizuku-lite.sh
#     sh /sdcard/Download/shizuku-lite.sh
#
# Uninstall everything it manages:   sh /sdcard/Download/shizuku-lite.sh uninstall

ACTION="${1:-install}"
BIN=/data/local/tmp/curl
CA=/data/local/tmp/cacert.pem
[ -x "$BIN" ] || { echo "!! $BIN missing — run the big self-contained installer once first (it drops curl here)."; exit 1; }

# ---- reach pm ----------------------------------------------------------------
if pm path android >/dev/null 2>&1; then PM_MODE=direct; WORK=/data/local/tmp/shizuku-apps
else echo "!! Can't reach 'pm'. Make sure Shizuku is running, then run this in aShell."; exit 1; fi
mkdir -p "$WORK" 2>/dev/null
echo ">> mode: $PM_MODE"

pm_has()     { pm path "$1" >/dev/null 2>&1; }
pm_install() { pm install -r "$1" >/dev/null 2>&1 && return 0
    s=$(stat -c%s "$1" 2>/dev/null); [ -n "$s" ] && cat "$1" | pm install -r -S "$s" >/dev/null 2>&1; }
pm_uninstall(){ pm uninstall --user 0 "$1" >/dev/null 2>&1; }

# ---- downloader: existing curl + device-DNS resolve + IP pinning -------------
CURL="$BIN"
ver=$("$CURL" --version 2>&1 | head -n1); [ -z "$ver" ] && { echo "!! curl won't run"; exit 1; }
echo ">> curl: $ver"
resolve() { ping -c 1 -W 2 "$1" 2>/dev/null | head -n1 | sed -n 's/^[^(]*(\([0-9.]*\)).*/\1/p'; }
RES=""; n=0
for h in f-droid.org apt.izzysoft.de api.github.com github.com \
         objects.githubusercontent.com release-assets.githubusercontent.com \
         codeload.github.com raw.githubusercontent.com mixplorer.com; do
    ip=$(resolve "$h"); [ -n "$ip" ] && { RES="$RES --resolve $h:443:$ip"; n=$((n+1)); }
done
echo ">> resolved $n/9 hosts"
OPTS=""; TU="https://f-droid.org/api/v1/packages/com.aistra.hail"
for base in "$RES" "$RES --dns-servers 1.1.1.1,8.8.8.8"; do
    for ca in "--cacert $CA" "--capath /apex/com.android.conscrypt/cacerts"; do
        [ -n "$("$CURL" $base $ca -fsSL "$TU" 2>/dev/null | head -c 30)" ] && { OPTS="$base $ca"; break 2; }
    done
done
[ -z "$OPTS" ] && { echo "!! network test failed"; exit 1; }
echo ">> network OK"
dl()  { "$CURL" $OPTS -fsSL --retry 3 -o "$2" "$1"; }
get() { "$CURL" $OPTS -fsL "$1"; }

install_url() { echo "== $1: downloading..."; apk="$WORK/$2.apk"
    dl "$3" "$apk" || { echo "!! $1: download failed"; return 1; }
    pm_install "$apk" && echo "== $1: installed OK" || echo "!! $1: install failed"; rm -f "$apk"; }
vercode()    { grep -o '"suggestedVersionCode": *"\{0,1\}[0-9]*' | grep -o '[0-9]*$'; }
src_fdroid() { vc=$(get "https://f-droid.org/api/v1/packages/$2" | vercode); [ -z "$vc" ] && { echo "!! $1: no F-Droid ver"; return 1; }; install_url "$1" "$2" "https://f-droid.org/repo/${2}_${vc}.apk"; }
src_izzy()   { vc=$(get "https://apt.izzysoft.de/fdroid/api/v1/packages/$2" | vercode); [ -z "$vc" ] && { echo "!! $1: no Izzy ver"; return 1; }; install_url "$1" "$2" "https://apt.izzysoft.de/fdroid/repo/${2}_${vc}.apk"; }
src_github() { apks=$(get "https://api.github.com/repos/$3/releases/latest" | tr ',' '\n' | grep browser_download_url | grep -o 'https://[^"]*\.apk')
    url=$(echo "$apks" | grep -v -E 'fdroid|x86|armeabi' | grep -m1 arm64); [ -z "$url" ] && url=$(echo "$apks" | grep -m1 -E 'arm64|universal'); [ -z "$url" ] && url=$(echo "$apks" | head -n1)
    [ -z "$url" ] && { echo "!! $1: no gh apk"; return 1; }; install_url "$1" "$2" "$url"; }
src_mixp()   { f=$(get "https://mixplorer.com/beta/" | grep -ao 'href="MiXplorer_[^"]*\.apk"' | cut -d'"' -f2 | head -1); [ -z "$f" ] && { echo "!! $1: no mixplorer"; return 1; }; install_url "$1" "$2" "https://mixplorer.com/beta/$f"; }

app() {
    if [ "$ACTION" = uninstall ]; then
        pm_has "$3" && { pm_uninstall "$3" && echo "== $2: uninstalled" || echo "!! $2: uninstall failed"; } || echo "== $2: not installed"; return; fi
    pm_has "$3" && { echo "== $2: already installed, skipping"; return; }
    "src_$1" "$2" "$3" "$4"; }

roster() {
    app github "ObtainX"       dev.bikram.obtainx                 bikram-agarwal/ObtainX
    app fdroid "Canta"         io.github.samolego.canta
    app fdroid "LogFox"        com.f0x1d.logfox
    app github "AntiSplit-M"   com.abdurazaaqmohammed.AntiSplit   AbdurazaaqMohammed/AntiSplit-M
    app github "WiFi Passwords" io.github.wifi_password_manager    Khh-vu/wifi-password-manager
    app izzy   "LinkSheet"     fe.linksheet
    app izzy   "Amarok-Hider"  deltazero.amarok.foss
    app github "de1984"        io.github.dorumrr.de1984           dorumrr/de1984
    app github "essentials"    com.sameerasw.essentials           sameerasw/essentials
    app github "Seal Plus"     com.maheshtechnicals.sealplus      MaheshTechnicals/Sealplus
    app fdroid "YTDLnis"       com.deniscerri.ytdl
    app github "XStreaming"    com.dev.xstreaming                 Geocld/XStreaming
    app fdroid "Permission Manager X" com.mirfatif.permissionmanagerx
    app mixp   "MiXplorer"     com.mixplorer
    app fdroid "Inure"         app.simple.inure
    app fdroid "Neo Store"     com.machiav3lli.fdroid
    app github "ShizuTools"    com.legendsayantan.adbtools        legendsayantan/ShizuTools
}
POST_UNINSTALL="org.fdroid.fdroid"

if [ "$ACTION" = uninstall ]; then echo "Removing managed apps..."; roster; echo; echo "Done."; exit 0; fi
roster
for p in $POST_UNINSTALL; do pm_has "$p" && pm_uninstall "$p" && echo "== removed replaced app: $p"; done
echo
echo "Done. Open each app once and grant it Shizuku permission when asked."
