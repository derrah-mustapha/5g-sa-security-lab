#!/bin/bash
# Insert the lab subscribers into the Open5GS UDR database (MongoDB).
# Idempotent: existing subscribers with the same IMSI are replaced.
set -euo pipefail
cd "$(dirname "$0")/.."

K=465B5CE8B199B49FAA5F0A2EE238A6BC
OPC=E8ED289DEBA952E4283B54E88E6183CA

sub() {  # imsi sst dnn
  cat <<EOF
db.subscribers.deleteMany({imsi: "$1"});
db.subscribers.insertOne({
  imsi: "$1",
  security: { k: "$K", opc: "$OPC", amf: "8000", sqn: NumberLong(0) },
  ambr: { downlink: { value: 1, unit: 3 }, uplink: { value: 1, unit: 3 } },
  slice: [{
    sst: $2, default_indicator: true,
    session: [{
      name: "$3", type: 3,
      qos: { index: 9, arp: { priority_level: 8, pre_emption_capability: 1, pre_emption_vulnerability: 1 } },
      ambr: { downlink: { value: 1, unit: 3 }, uplink: { value: 1, unit: 3 } }
    }]
  }],
  access_restriction_data: 32, subscriber_status: 0, network_access_mode: 0,
  subscribed_rau_tau_timer: 12, schema_version: 1
});
EOF
}

{
  sub 999700000000001 1 internet
  sub 999700000000002 2 urllc
  echo 'print("subscribers: " + db.subscribers.countDocuments())'
} | docker compose exec -T mongo mongosh --quiet open5gs
