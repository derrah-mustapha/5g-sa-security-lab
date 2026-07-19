#!/usr/bin/env python3
"""Print the public half of Open5GS' home-network keys (needed in the UE config for SUCI).
    python3 scripts/derive_hnet_pubkey.py        (needs the 'cryptography' package)
Profile A = X25519 (raw 32 bytes); Profile B = secp256r1 (compressed point)."""
import pathlib
from cryptography.hazmat.primitives import serialization as s

d = pathlib.Path(__file__).resolve().parent.parent / "config/open5gs/hnet"
for f in sorted(d.glob("*.key")):
    k = s.load_pem_private_key(f.read_bytes(), None)
    if f.name.startswith("curve25519"):
        pub = k.public_key().public_bytes(s.Encoding.Raw, s.PublicFormat.Raw)
    else:
        pub = k.public_key().public_bytes(s.Encoding.X962, s.PublicFormat.CompressedPoint)
    print(f"{f.name:20s} {pub.hex()}")
