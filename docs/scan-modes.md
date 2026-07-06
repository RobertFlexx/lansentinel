# scan modes

lansentinel has three scan modes: `auto`, `arp`, and `full`. they all use normal tcp connect probes for service checks, but they choose different sets of ip addresses to probe.

the short version is: start with `auto`, use `arp` when you want the quietest pass, and use `full` only when you really mean to sweep the whole range.

## auto

`auto` is the default.

small ranges, currently 32 hosts or fewer, use a full tcp sweep. larger ranges use arp-seeded tcp probes unless `--allow-large-scan` is provided.

```sh
./lansentinel --scan 192.168.1.0/24 --scan-mode auto --ports common
```

use this when you want safe defaults and do not want to think too hard about scan planning.

## arp

`arp` mode only probes ip addresses already visible in the local arp cache and inside the selected range.

```sh
./lansentinel --scan 192.168.1.0/24 --scan-mode arp --ports common
```

this mode is fast and quiet. it is also incomplete by design. it can miss devices that have not recently talked to your machine, devices that are asleep, guest wifi clients, firewalled hosts, and anything hidden by access point client isolation.

use this when you want a conservative discovery pass and you are okay with missing quiet devices.

## full

`full` mode probes every usable ip in the selected cidr range.

```sh
./lansentinel --scan 192.168.1.0/24 --scan-mode full --allow-large-scan --ports common
```

full scans can discover more services, but they are slower and noisier because they create tcp connect attempts across the range. for ranges larger than 32 hosts, lansentinel requires `--allow-large-scan`.

use this when you own the network, understand the traffic it will create, and want the most direct discovery pass.

## why allow-large-scan exists

home routers and small networks can get weird under careless scans. more importantly, it is easy to mistype a cidr and accidentally ask for much more traffic than you meant.

`--allow-large-scan` is a speed bump. it makes large full sweeps intentional.

## choosing a mode

- use `auto` for normal day-to-day discovery.
- use `arp` when you want lower noise and can accept missing quiet devices.
- use `full` when you need broad coverage and have permission to probe the whole range.

if you are not sure, run this first:

```sh
./lansentinel --explain-scan
```
