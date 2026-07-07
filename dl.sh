#!/system/bin/sh
# dl.sh — download ANY url in the raw Android shell, no /etc/resolv.conf needed.
# Resolves each host with the phone's own resolver (ping -> netd) and hands the
# IP to the bundled static curl, following redirects and re-resolving each hop.
#
# Setup: run the shizuku-apps installer once (it puts curl + cacert.pem in
# /data/local/tmp). Then use this for anything:
#     sh /sdcard/Download/dl.sh https://example.com/file.apk
#     sh /sdcard/Download/dl.sh https://example.com/file.apk /sdcard/Download/file.apk
#
# To also INSTALL an apk you just downloaded:
#     sh /sdcard/Download/dl.sh <url> /data/local/tmp/x.apk && pm install -r /data/local/tmp/x.apk

CURL=/data/local/tmp/curl
CA=/data/local/tmp/cacert.pem
[ -x "$CURL" ] || { echo "!! $CURL not found — run the shizuku-apps installer once first."; exit 1; }

url="$1"
[ -z "$url" ] && { echo "usage: sh dl.sh <url> [output-file]"; exit 1; }
out="${2:-$(basename "$url")}"

resolve() { ping -c 1 -W 2 "$1" 2>/dev/null | head -n1 | sed -n 's/^[^(]*(\([0-9.]*\)).*/\1/p'; }
RES=""
add_host() {
    h="$1"
    case " $RES " in *" --resolve $h:443:"*) return 0 ;; esac   # already resolved
    ip=$(resolve "$h")
    if [ -z "$ip" ]; then echo "!! could not resolve $h"; return 1; fi
    RES="$RES --resolve $h:443:$ip --resolve $h:80:$ip"
    echo ">> $h -> $ip"
}

# walk redirects (max 6 hops), resolving each new host before asking curl
i=0
while [ $i -lt 6 ]; do
    host=$(printf '%s' "$url" | sed -n 's#^[a-zA-Z][a-zA-Z0-9+.-]*://\([^/]*\).*#\1#p' | sed 's/:.*//')
    [ -z "$host" ] && { echo "!! bad url: $url"; exit 1; }
    add_host "$host" || exit 1
    loc=$("$CURL" $RES --cacert "$CA" -sSI "$url" 2>/dev/null | tr -d '\r' | sed -n 's/^[Ll]ocation: *//p' | tail -n1)
    if [ -n "$loc" ]; then url="$loc"; i=$((i+1)); continue; fi
    break
done

echo ">> downloading -> $out"
if "$CURL" $RES --cacert "$CA" -fL --retry 3 -o "$out" "$url"; then
    echo ">> saved: $out ($(wc -c < "$out" 2>/dev/null) bytes)"
else
    echo "!! download failed"; exit 1
fi
