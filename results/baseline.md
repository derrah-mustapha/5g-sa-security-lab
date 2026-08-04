# Results: baseline profile

_generated 2026-11-09 18:18 UTC by scripts/run_experiments.sh_

## E1/E2. Capture of a fresh registration + PDU session
### Subscriber identity sent by the UE (Registration Request)
2 .... 0000 = Protection scheme Id: NULL scheme (0)
2 Home network public key identifier: 0
1 MSIN: 0000000001
1 MSIN: 0000000002

### NAS algorithms chosen by the AMF (Security Mode Command)
2 0000 .... = Type of ciphering algorithm: 5G-EA0 (null ciphering algorithm) (0)
2 .... 0010 = Type of integrity protection algorithm: 128-5G-IA2 (2)

### Service-based interface (core network control plane)
- readable HTTP/2 frames on port 7777 : 90
- encrypted TLS application-data records: 0
- lines exposing a SUPI (imsi-9997..) : 104
- example requests an eavesdropper can read:
    3 PATCH	/nnrf-nfm/v1/nf-instances/e3a4861c-dc69-41f1-ad8f-6de7e9557db8
    2 POST	/nsmf-pdusession/v1/sm-contexts
    2 POST	/npcf-am-policy-control/v1/policies
    2 POST	/nausf-auth/v1/ue-authentications
    1 PUT	/nudm-uecm/v1/imsi-999700000000002/registrations/amf-3gpp-access

## E3. Rogue gNB (unauthorised radio node, 10.10.2.66) tries to join the AMF
```
[2026-11-09 18:19:17.505] [sctp] [info] Trying to establish SCTP connection... (10.10.2.12:38412)
[2026-11-09 18:19:17.507] [sctp] [info] SCTP connection established (10.10.2.12:38412)
[2026-11-09 18:19:17.507] [sctp] [debug] SCTP association setup ascId[19]
[2026-11-09 18:19:17.508] [ngap] [debug] Sending NG Setup Request
[2026-11-09 18:19:17.516] [ngap] [debug] NG Setup Response received
[2026-11-09 18:19:17.516] [ngap] [info] NG Setup procedure is successful
```
**Result: the AMF accepted the rogue gNB (NG Setup completed).**

## E4. Slice isolation (ue1 10.45.0.4 on eMBB -> ue2 10.46.0.4 on URLLC)
```
--- 10.46.0.4 ping statistics ---
3 packets transmitted, 2 received, +2 errors, 33.3333% packet loss, time 2041ms
rtt min/avg/max/mdev = 0.785/2.173/3.561/1.388 ms
```

## E5. Performance through the UPF (dn-server 10.10.3.50)

| slice | UE IP | RTT avg (ms) | TCP throughput (Mbit/s) |
|---|---|---|---|
| ue1 | 10.45.0.4 | 0.383 | 754 |
| ue2 | 10.46.0.4 | 0.406 | 557 |
