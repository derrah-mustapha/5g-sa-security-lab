#!/usr/bin/env python3
"""Generate the Open5GS + UERANSIM configs for the two lab profiles.

    baseline  - Open5GS defaults: null ciphering allowed, SUPI sent in clear (null
                scheme), SBI over plain HTTP.  This is the "before" in the security
                analysis.
    hardened  - NEA0/NIA0 removed, SUCI concealed with ECIES Profile A, SBI over TLS.

The pristine upstream Open5GS configs live in config/open5gs/ and are only read.
Output goes to config/profiles/<profile>/.
"""
import os
import pathlib
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
UPSTREAM = ROOT / "config" / "open5gs"
OUT = ROOT / "config" / "profiles"

# ---- lab addressing -------------------------------------------------------
CORE = "10.10.1."   # control plane (SBI, PFCP)       - docker network "core" (internal)
RAN = "10.10.2."    # N2 / N3 / radio simulation      - docker network "ran"  (internal)
IP = {"mongo": 2, "nrf": 10, "scp": 11, "amf": 12, "smf": 13, "upf": 14,
      "ausf": 15, "udm": 16, "udr": 17, "pcf": 18, "bsf": 19, "nssf": 20}
GNB_IP, ROGUE_IP, UE1_IP, UE2_IP = RAN + "20", RAN + "66", RAN + "31", RAN + "32"
AMF_N2, UPF_N3 = RAN + "12", RAN + "14"

PLMN = {"mcc": 999, "mnc": 70}
SLICES = [
    {"name": "embb", "sst": 1, "dnn": "internet", "subnet": "10.45.0.0/24", "gw": "10.45.0.1"},
    {"name": "urllc", "sst": 2, "dnn": "urllc", "subnet": "10.46.0.0/24", "gw": "10.46.0.1"},
]
SUBSCRIBERS = [
    {"imsi": "999700000000001", "slice": SLICES[0], "ue": "ue1"},
    {"imsi": "999700000000002", "slice": SLICES[1], "ue": "ue2"},
]
K = "465B5CE8B199B49FAA5F0A2EE238A6BC"
OPC = "E8ED289DEBA952E4283B54E88E6183CA"
# Public half of Open5GS' shipped home-network key id 1 (ECIES Profile A / X25519).
# Derived with scripts/derive_hnet_pubkey.py from config/open5gs/hnet/curve25519-1.key
HN_PUBKEY = "e421686f6fb2d70e3fa28d940494095686c3179fef53514667a6ed106b8a7d3d"

TLS_DIR = "/opt/open5gs/etc/open5gs/tls"
MTLS = os.environ.get("SBI_MTLS", "1") == "1"      # mutual TLS on the SBI (set SBI_MTLS=0 for server-only TLS)


def load(nf):
    return yaml.safe_load((UPSTREAM / f"{nf}.yaml").read_text())


def bind(entries, ip):
    """Replace 'dev: eth0' with an explicit address on every server entry."""
    for e in entries or []:
        e.pop("dev", None)
        e["address"] = ip


def sessions():
    return [{"subnet": s["subnet"], "gateway": s["gw"], "dnn": s["dnn"]} for s in SLICES]


def uri(nf, tls):
    # the shipped certificates carry CN=<nf>.localdomain, so TLS needs those names
    # NFs advertise an FQDN without a port, so peers assume the https default (443)
    return f"https://{nf}.localdomain" if tls else f"http://{nf}:7777"


def build(profile):
    hard = profile == "hardened"
    tls = hard
    cfgs = {}

    for nf in ("nrf", "scp", "amf", "smf", "upf", "ausf", "udm", "udr", "pcf", "bsf", "nssf"):
        c = load(nf)
        body = c[nf]
        ip = CORE + str(IP[nf])
        if "sbi" in body:
            bind(body["sbi"].get("server"), f"{nf}.localdomain" if tls else ip)
            for srv in body["sbi"].get("server") or []:
                srv["port"] = 443 if tls else 7777
            client = body["sbi"].get("client", {})
            if "scp" in client:
                if tls:
                    # Hardened profile: NFs discover each other through the NRF and talk
                    # directly (3GPP "direct communication"), no SCP in the path. The SCP
                    # of Open5GS 2.7.2 stops accepting connections once TLS is enabled.
                    client.pop("scp")
                    client["nrf"] = [{"uri": uri("nrf", tls)}]
                else:
                    client["scp"] = [{"uri": uri("scp", tls)}]
            if "nrf" in client:
                client["nrf"] = [{"uri": uri("nrf", tls)}]
        if "metrics" in body:
            bind(body["metrics"].get("server"), ip)
        if "db_uri" in c:
            c["db_uri"] = "mongodb://mongo/open5gs"

        if nf == "amf":
            bind(body["ngap"]["server"], AMF_N2)
            body["plmn_support"] = [{
                "plmn_id": PLMN,
                "s_nssai": [{"sst": s["sst"]} for s in SLICES],
            }]
            body["security"] = (
                {"integrity_order": ["NIA2", "NIA1"], "ciphering_order": ["NEA2", "NEA1"]}
                if hard else
                {"integrity_order": ["NIA2", "NIA1", "NIA0"], "ciphering_order": ["NEA0", "NEA1", "NEA2"]}
            )
        if nf == "nssf":
            # one network slice instance per slice, both served by the lab NRF
            body["sbi"]["client"]["nsi"] = [{"uri": uri("nrf", tls), "s_nssai": {"sst": sl["sst"]}} for sl in SLICES]
        if nf == "smf":
            bind(body["pfcp"]["server"], ip)
            body["pfcp"]["client"] = {"upf": [{"address": CORE + str(IP["upf"])}]}
            bind(body["gtpc"]["server"], ip)
            bind(body["gtpu"]["server"], ip)
            body["session"] = sessions()
            body["dns"] = ["8.8.8.8", "1.1.1.1"]
            body.pop("freeDiameter", None)
        if nf == "upf":
            bind(body["pfcp"]["server"], ip)
            body["pfcp"].pop("client", None)
            bind(body["gtpu"]["server"], UPF_N3)
            body["session"] = sessions()

        if tls and "sbi" in body:      # the UPF has no SBI interface
            enable_tls(nf, body)
        cfgs[nf] = c
    return cfgs


def enable_tls(nf, body):
    """SBI over HTTPS. With MTLS every NF also presents a CA-signed client certificate
    and every server requires one."""
    server = {"scheme": "https",
              "private_key": f"{TLS_DIR}/{nf}.key", "cert": f"{TLS_DIR}/{nf}.crt"}
    client = {"scheme": "https", "cacert": f"{TLS_DIR}/ca.crt"}
    if MTLS:
        server.update(verify_client=True, verify_client_cacert=f"{TLS_DIR}/ca.crt")
        client.update(client_private_key=f"{TLS_DIR}/{nf}.key", client_cert=f"{TLS_DIR}/{nf}.crt")
    body["default"] = {"tls": {"server": server, "client": client}}


# ---- UERANSIM -------------------------------------------------------------
def gnb_yaml(ip, nci):
    return f"""mcc: '{PLMN['mcc']}'
mnc: '{PLMN['mnc']}'
nci: '{nci}'
idLength: 32
tac: 1
linkIp: {ip}
ngapIp: {ip}
gtpIp: {ip}
amfConfigs:
  - address: {AMF_N2}
    port: 38412
slices:
{chr(10).join(f"  - sst: {s['sst']}" for s in SLICES)}
ignoreStreamIds: true
"""


def ue_yaml(sub, gnb_ip, conceal):
    sl = sub["slice"]
    scheme = f"""protectionScheme: 1
homeNetworkPublicKey: '{HN_PUBKEY}'
homeNetworkPublicKeyId: 1
routingIndicator: '0000'
""" if conceal else "protectionScheme: 0\n"
    return f"""supi: 'imsi-{sub['imsi']}'
mcc: '{PLMN['mcc']}'
mnc: '{PLMN['mnc']}'
{scheme}key: '{K}'
op: '{OPC}'
opType: 'OPC'
amf: '8000'
imei: '356938035643803'
imeiSv: '4370816125816151'
gnbSearchList:
  - {gnb_ip}
uacAic: {{mps: false, mcs: false}}
uacAcc: {{normalClass: 0, class11: false, class12: false, class13: false, class14: false, class15: false}}
sessions:
  - type: 'IPv4'
    apn: '{sl['dnn']}'
    slice: {{sst: {sl['sst']}}}
configured-nssai:
  - sst: {sl['sst']}
default-nssai:
  - sst: {sl['sst']}
integrity: {{IA1: true, IA2: true, IA3: true}}
ciphering: {{EA1: true, EA2: true, EA3: true}}
integrityMaxRate: {{uplink: 'full', downlink: 'full'}}
"""


def main():
    for profile in ("baseline", "hardened"):
        out = OUT / profile
        out.mkdir(parents=True, exist_ok=True)
        for nf, cfg in build(profile).items():
            (out / f"{nf}.yaml").write_text(yaml.safe_dump(cfg, sort_keys=False))
        (out / "gnb.yaml").write_text(gnb_yaml(GNB_IP, "0x000000010"))
        (out / "rogue-gnb.yaml").write_text(gnb_yaml(ROGUE_IP, "0x0000000ff"))
        for sub in SUBSCRIBERS:
            (out / f"{sub['ue']}.yaml").write_text(
                ue_yaml(sub, GNB_IP, conceal=(profile == "hardened")))
        print(f"wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
