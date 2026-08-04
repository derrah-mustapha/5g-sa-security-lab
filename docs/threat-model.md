# Threat model (STRIDE) of the lab

Scope: the 5G SA core and its interfaces as deployed in `docker-compose.yml`. The attacker models are
(A1) a passive observer on a core or RAN network segment, (A2) an active host on the RAN segment,
(A3) a compromised or malicious subscriber device.

| Interface / asset | STRIDE | Threat | Lab evidence | Mitigation in `hardened` | Residual risk |
|---|---|---|---|---|---|
| Uu: subscriber identity | **I**nformation disclosure | Passive observer reads the permanent identity (SUPI) from the Registration Request | E1: baseline pcap shows null scheme + MSIN | SUCI with ECIES Profile A | Depends on the UE/SIM being provisioned with a scheme; network still accepts null scheme |
| Uu/N1: NAS confidentiality | **I** | Signalling sent unencrypted (5G-EA0) | E1: Security Mode Command selects EA0 | Remove NEA0/NIA0 from AMF preference lists | UEs that support only EA0 can no longer register (intended) |
| N2: gNB admission | **S**poofing, **T**ampering | Unauthorised node completes NG Setup and can send NGAP messages | E3: rogue gNB accepted | Source allow-list on the AMF | Address spoofing on the same L2 segment; needs IPsec/mutual authentication on N2 |
| SBI: confidentiality | **I** | A1 reads SUPIs, auth data and session context between NFs | E2: 104 SUPI-bearing lines in clear | HTTPS everywhere | Certificates are test certs; no revocation or rotation in the lab |
| SBI: caller identity | **S** | A host on the core network calls NF APIs as another NF | Plain HTTP baseline accepts any caller | mTLS with `verify_client`, CA-signed client certs | A compromised NF with a valid cert is trusted |
| N3/N6: slice separation | **E**levation of privilege, **I** | A UE in one slice reaches UEs/services in another | E4: cross-slice ping passes | UPF FORWARD DROP between slice subnets | Isolation is IP-level only; no per-slice rate enforcement |
| Subscriber database (MongoDB) | **T**, **I** | Anyone on `core` can read keys (K/OPc) | Not tested; mongo listens without authentication on the internal network | Network is internal and only NFs are attached | No DB authentication or encryption at rest: a gap for any real deployment |
| UE credentials | **S** | Stolen K/OPc lets an attacker impersonate a subscriber | Lab keys are well-known test values | Out of scope for the core | Real deployments keep K/OPc in a SIM/HSM |
| Availability of NRF/AMF | **D**enial of service | Floods of registrations or NRF requests | Not tested | None (no rate limiting configured) | Open item |

## Out of scope / not tested

Radio-layer attacks, user-plane (N3) encryption, SEPP/roaming interfaces, N4 (PFCP) authentication,
and denial-of-service testing. N4 between SMF and UPF is plain UDP in both profiles.
