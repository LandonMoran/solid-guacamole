#!/system/bin/sh
# setup-kit.sh — assemble ONE folder with every shell tool we built.
# Run once:   sh /sdcard/Download/setup-kit.sh
# Result:     /sdcard/shizuku-kit/  containing curl, cacert.pem, dl.sh,
#             shizuku-lite.sh, run.sh (restore helper), and README.txt.

KIT=/sdcard/shizuku-kit
BIN=/data/local/tmp/curl
CA=/data/local/tmp/cacert.pem
REPO="https://cdn.jsdelivr.net/gh/landonmoran/solid-guacamole@1b15f48a4e2d159b19ed2b53a4fd7e10b56a7396"

[ -x "$BIN" ] || { echo "!! $BIN not found. Run the big self-contained installer once first."; exit 1; }
mkdir -p "$KIT" || { echo "!! can't create $KIT"; exit 1; }
echo ">> kit folder: $KIT"

# inline downloader (resolve via device DNS, pin the IP)
resolve() { ping -c 1 -W 2 "$1" 2>/dev/null | head -n1 | sed -n 's/^[^(]*(\([0-9.]*\)).*/\1/p'; }
JIP=$(resolve cdn.jsdelivr.net)
[ -z "$JIP" ] && { echo "!! couldn't resolve cdn.jsdelivr.net"; exit 1; }
GET="$BIN --resolve cdn.jsdelivr.net:443:$JIP --cacert $CA -fsSL"
fetch() { echo ">> fetching $1"; $GET "$REPO/$1" -o "$KIT/$1" || echo "!! failed: $1"; }

# 1) back up the binary + certs INTO the kit (portable copies)
cp "$BIN" "$KIT/curl"       && echo ">> copied curl"
cp "$CA"  "$KIT/cacert.pem" && echo ">> copied cacert.pem"

# 2) pull the scripts into the kit
fetch dl.sh
fetch shizuku-lite.sh

# 3) restore helper — puts curl back in an executable spot if it's ever wiped
cat > "$KIT/run.sh" <<'EOF'
#!/system/bin/sh
# Restores curl to /data/local/tmp (executable) from the kit, if missing.
K=/sdcard/shizuku-kit
if [ ! -x /data/local/tmp/curl ]; then
    cp "$K/curl" /data/local/tmp/curl && chmod 755 /data/local/tmp/curl && echo "restored curl"
fi
[ -f /data/local/tmp/cacert.pem ] || cp "$K/cacert.pem" /data/local/tmp/cacert.pem
echo "Ready. Commands:"
echo "  install/update apps :  sh $K/shizuku-lite.sh"
echo "  download anything   :  sh $K/dl.sh <url> [outfile]"
EOF
echo ">> wrote run.sh"

# 4) README
cat > "$KIT/README.txt" <<EOF
Shizuku shell kit — everything to install/update apps from aShell, no browser.

FILES
  curl            static downloader (backup of /data/local/tmp/curl)
  cacert.pem      HTTPS certificates
  dl.sh           download any url:        sh $KIT/dl.sh <url> [outfile]
  shizuku-lite.sh install/update the apps: sh $KIT/shizuku-lite.sh
  run.sh          restore curl if wiped:   sh $KIT/run.sh
  README.txt      this file

NOTES
  - curl must live in /data/local/tmp to run (/sdcard is no-exec). The copy
    here is a backup; run.sh restores it after a factory reset.
  - Everything persists across reboots and system updates. Only a factory
    reset wipes it — and this folder lets you rebuild in seconds.
EOF
echo ">> wrote README.txt"

echo
echo "Done. Kit is at $KIT :"
ls -la "$KIT"
