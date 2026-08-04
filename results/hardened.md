# Results: hardened profile

_generated 2026-11-09 18:15 UTC by scripts/run_experiments.sh_

## E1/E2. Capture of a fresh registration + PDU session
### Subscriber identity sent by the UE (Registration Request)
2 .... 0001 = Protection scheme Id: ECIES scheme profile A (1)
2 Home network public key identifier: 1

### NAS algorithms chosen by the AMF (Security Mode Command)
2 0010 .... = Type of ciphering algorithm: 128-5G-EA2 (2)
2 .... 0010 = Type of integrity protection algorithm: 128-5G-IA2 (2)

### Service-based interface (core network control plane)
- readable HTTP/2 frames on port 7777 : 0
- encrypted TLS application-data records: 89
- lines exposing a SUPI (imsi-9997..) : 0

## E3. Rogue gNB (unauthorised radio node, 10.10.2.66) tries to join the AMF
```
[2026-11-09 18:16:35.791] [sctp] [info] Trying to establish SCTP connection... (10.10.2.12:38412)
```
**Result: the AMF never saw the rogue gNB (N2 allow-list dropped its SCTP packets).**

## E4. Slice isolation (ue1 10.45.0.4 on eMBB -> ue2 10.46.0.4 on URLLC)
```
--- 10.46.0.4 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 3076ms

```

## E5. Performance through the UPF (dn-server 10.10.3.50)

| slice | UE IP | RTT avg (ms) | TCP throughput (Mbit/s) |
|---|---|---|---|
| ue1 | 10.45.0.4 | 0.859 | 807 |
| ue2 | 10.46.0.4 | 0.640 | 759 |
