#!/bin/bash
# Capture the N2 (NGAP/NAS over SCTP) and SBI (HTTP/2) traffic seen by the AMF while the
# UEs perform a fresh registration + PDU session establishment.
#
#   scripts/capture.sh <label> [seconds]      ->  captures/<label>.pcap
#
# The sniffer is a throw-away container that joins the AMF's network namespace, so it
# sees both the core (SBI) and ran (N2) interfaces without touching the host network.
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=${1:?usage: capture.sh <label> [seconds]}
SECS=${2:-20}
mkdir -p captures
rm -f "captures/$LABEL.pcap"

AMF=$(docker compose ps -q amf)
docker rm -f lab-sniffer >/dev/null 2>&1 || true
docker run -d --name lab-sniffer --net "container:$AMF" --cap-add NET_RAW --cap-add NET_ADMIN \
  -v "$PWD/captures:/captures" nicolaka/netshoot \
  tcpdump -U -i any -n -w "/captures/$LABEL.pcap" >/dev/null
sleep 2

docker compose restart ue1 ue2 >/dev/null 2>&1      # forces a fresh registration + PDU session
sleep "$SECS"

docker stop -t 3 lab-sniffer >/dev/null
docker rm lab-sniffer >/dev/null
# the sniffer wrote the file as root: hand it back to the invoking user
docker run --rm -v "$PWD/captures:/c" nicolaka/netshoot chown "$(id -u):$(id -g)" "/c/$LABEL.pcap"
echo "captured $(du -h "captures/$LABEL.pcap" | cut -f1) -> captures/$LABEL.pcap"
