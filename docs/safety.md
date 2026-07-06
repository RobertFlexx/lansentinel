# safety

only scan networks you own or have permission to test.

lansentinel is a discovery and monitoring tool. it does not implement exploit behavior, credential guessing, password attacks, packet sniffing, stealth scanning, evasion, or vulnerability exploitation.

## what traffic it creates

lansentinel uses normal tcp connect probes against the ports you choose. if a port is open, it may do a small amount of identification around that service. it can also read local arp cache data on linux, such as `/proc/net/arp`, to attach known mac addresses and tiny vendor hints.

reading the arp cache does not query the router, bypass network isolation, or discover devices your machine has no local knowledge of.

unlike nmap, lansentinel does not send raw arp probes or icmp ping sweeps. that keeps the implementation simpler and less privileged, but it also means lansentinel may report fewer hosts than nmap on the same subnet.

## why scans can miss devices

some devices may not appear if they are asleep, firewalled, on guest wifi, behind client isolation, across a vlan boundary, or just not listening on the ports you selected.

arp-seeded scans can also miss anything not already visible in your local arp cache. that is the tradeoff: quieter scan, less complete view.

## router hints are not router access

`--router 192.168.1.1` only uses the address as a hint and assumes a likely `/24` range. it does not log into the router, use a router api, or read a router client list.

## safer habits

- start with `--scan-mode auto`.
- keep the cidr small and explicit.
- use `--ports common` or a short comma-separated list.
- use `--explain-scan` when you are unsure what will happen.
- only use `--scan-mode full --allow-large-scan` when you really mean it.

the tool tries to have safe defaults, but the operator is still responsible for where the packets go.
