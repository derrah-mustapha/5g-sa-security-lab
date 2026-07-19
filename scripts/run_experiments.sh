#!/bin/bash
# Run the full experiment set against the running lab and write results/<profile>.md
#
#   scripts/lab.sh up baseline  && scripts/run_experiments.sh baseline
#   scripts/lab.sh up hardened  && scripts/run_experiments.sh hardened
#
# Experiments: E1 identity + NAS security (pcap)   E2 SBI exposure (pcap)
#              E3 rogue gNB on N2                  E4 slice isolation
#              E5 throughput and latency per slice
set -uo pipefail
cd "$(dirname "$0")/.."
PROFILE=${1:?usage: run_experiments.sh baseline|hardened}
export PROFILE
[ "$PROFILE" = hardened ] && export SLICE_ISOLATION=yes N2_ALLOW=10.10.2.20
mkdir -p results
OUT="results/$PROFILE.md"

ue_ip() { docker compose exec -T "$1" ip -4 -o addr show uesimtun0 | awk '{print $4}' | cut -d/ -f1; }

{
echo "# Results: $PROFILE profile"
echo
echo "_generated $(date -u '+%Y-%m-%d %H:%M UTC') by scripts/run_experiments.sh_"
echo

echo "## E1/E2. Capture of a fresh registration + PDU session"
./scripts/capture.sh "$PROFILE" 25 >/dev/null
./scripts/analyze_pcap.sh "$PROFILE" | sed '1,2d'
echo

echo "## E3. Rogue gNB (unauthorised radio node, 10.10.2.66) tries to join the AMF"
echo '```'
timeout 20 docker compose --profile rogue run --rm rogue-gnb 2>&1 \
  | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'NG Setup|SCTP|ngap|Connecting|failed|error' | head -6
echo '```'
docker compose --profile rogue rm -sf rogue-gnb >/dev/null 2>&1
if docker compose logs amf 2>&1 | grep -q "gNB-N2\[10.10.2.66"; then
  echo "**Result: the AMF accepted the rogue gNB (NG Setup completed).**"
else
  echo "**Result: the AMF never saw the rogue gNB (N2 allow-list dropped its SCTP packets).**"
fi
echo

UE1=$(ue_ip ue1); UE2=$(ue_ip ue2)
echo "## E4. Slice isolation (ue1 $UE1 on eMBB -> ue2 $UE2 on URLLC)"
echo '```'
docker compose exec -T ue1 ping -I uesimtun0 -c 4 -W 2 "$UE2" 2>&1 | tail -3
echo '```'
echo

echo "## E5. Performance through the UPF (dn-server 10.10.3.50)"
echo
echo "| slice | UE IP | RTT avg (ms) | TCP throughput (Mbit/s) |"
echo "|---|---|---|---|"
for ue in ue1 ue2; do
  ip=$(ue_ip $ue)
  rtt=$(docker compose exec -T $ue ping -I uesimtun0 -c 10 -i 0.2 -W 2 10.10.3.50 2>&1 | awk -F'/' '/rtt/{print $5}')
  bw=$(docker compose exec -T $ue iperf3 -B "$ip" -c 10.10.3.50 -t 5 -J 2>/dev/null \
        | python3 -c 'import sys,json; d=json.load(sys.stdin); print(round(d["end"]["sum_received"]["bits_per_second"]/1e6))' 2>/dev/null)
  echo "| $ue | $ip | ${rtt:-n/a} | ${bw:-n/a} |"
done
} > "$OUT"

echo "wrote $OUT"
