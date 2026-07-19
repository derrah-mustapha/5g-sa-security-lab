#!/bin/bash
# UPF start-up: create the ogstun device with one gateway address per slice,
# NAT the UE pools towards the data network, then run the Open5GS UPF.
# Slice isolation (hardened profile): drop traffic between the slice subnets.
set -e

ip tuntap add name ogstun mode tun 2>/dev/null || true
ip addr add 10.45.0.1/24 dev ogstun 2>/dev/null || true
ip addr add 10.46.0.1/24 dev ogstun 2>/dev/null || true
ip link set ogstun up

iptables -t nat -A POSTROUTING -s 10.45.0.0/24 ! -o ogstun -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.46.0.0/24 ! -o ogstun -j MASQUERADE

if [ "${SLICE_ISOLATION:-no}" = "yes" ]; then
  iptables -A FORWARD -s 10.45.0.0/24 -d 10.46.0.0/24 -j DROP
  iptables -A FORWARD -s 10.46.0.0/24 -d 10.45.0.0/24 -j DROP
  echo "slice isolation: ON"
fi

exec open5gs-upfd -c /opt/open5gs/etc/open5gs/upf.yaml
