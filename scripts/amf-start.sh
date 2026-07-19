#!/bin/bash
# AMF start-up. NGAP/SCTP on N2 has no authentication of its own, so the hardened
# profile restricts who may talk to the AMF: only the provisioned gNB address is
# allowed, every other SCTP packet is dropped (matched by protocol number 132 so no
# xt_sctp kernel module is needed).
set -e

if [ -n "${N2_ALLOW:-}" ]; then
  iptables -A INPUT -p 132 -s "$N2_ALLOW" -j ACCEPT
  iptables -A INPUT -p 132 -j DROP
  echo "N2 firewall: SCTP accepted only from $N2_ALLOW"
fi

exec su -s /bin/bash open5gs -c "exec open5gs-amfd -c /opt/open5gs/etc/open5gs/amf.yaml"
