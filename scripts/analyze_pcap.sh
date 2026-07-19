#!/bin/bash
# Summarise the security-relevant content of a capture made with capture.sh.
#   scripts/analyze_pcap.sh <label>
# tshark runs in a container (nicolaka/netshoot), nothing needs installing on the host.
set -euo pipefail
cd "$(dirname "$0")/.."
LABEL=${1:?usage: analyze_pcap.sh <label>}
PCAP="/c/$LABEL.pcap"
T() { docker run --rm -v "$PWD/captures:/c" nicolaka/netshoot tshark -r "$PCAP" "$@" 2>/dev/null; }

echo "## N2 (NGAP/NAS) analysis of $LABEL.pcap"
echo
echo "### Subscriber identity sent by the UE (Registration Request)"
T -Y 'nas-5gs.mm.message_type == 0x41' -V | grep -E 'Protection scheme Id|MSIN:|Home network public key' \
  | sed 's/^ *//' | sort | uniq -c | sed 's/^ *//'
echo
echo "### NAS algorithms chosen by the AMF (Security Mode Command)"
T -Y 'nas-5gs.mm.message_type == 0x5d' -V | grep -E 'Type of (ciphering|integrity)' | sed 's/^ *//' | sort | uniq -c | sed 's/^ *//'
echo
echo "### Service-based interface (core network control plane)"
HTTP2=$(T -d tcp.port==7777,http2 -Y http2 | wc -l)
TLS=$(T -Y 'tls.record.content_type == 23' | wc -l)
LEAK=$(T -d tcp.port==7777,http2 -Y http2 -V | grep -cE 'imsi-9997' || true)
echo "- readable HTTP/2 frames on port 7777 : $HTTP2"
echo "- encrypted TLS application-data records: $TLS"
echo "- lines exposing a SUPI (imsi-9997..) : $LEAK"
if [ "$HTTP2" -gt 0 ]; then
  echo "- example requests an eavesdropper can read:"
  T -d tcp.port==7777,http2 -Y 'http2.headers.method' -T fields -e http2.headers.method -e http2.headers.path \
    | sort | uniq -c | sort -rn | head -5 | sed 's/^ */    /'
fi
