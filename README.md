# lansentinel

lansentinel is a small native lan discovery and service monitoring tool written in pony. it helps you answer the normal homelab question of "what is alive on this network, what ports are open, and are the services i care about still up" without pulling in nmap, shelling out to system tools, or pretending to do deep security scanning.

it is meant for networks you own: homelabs, routers, nas boxes, printers, game servers, dev services, local web apps, and other little things that quietly disappear at the worst time.

## what it does

- discovers devices with bounded tcp connect probes.
- can seed discovery from the local arp cache on linux.
- supports explicit scan modes: `auto`, `arp`, and `full`.
- refuses risky large full scans unless you opt in with `--allow-large-scan`.
- monitors tcp services like `host:port`.
- monitors simple `http://` urls with a basic tcp/http check.
- writes human output, json output, csv inventory, and one-shot prometheus text.
- can save an inventory, load it later, and monitor the services it found.
- reads a tiny config file for repeatable watch setups.
- uses pony actors for concurrent scan probes and service watchers.
- does not use ffi and does not shell out to `nmap`, `arp`, `ip`, or `netstat`.

## what it does not do

- it does not exploit anything.
- it does not guess passwords or credentials.
- it does not sniff packets.
- it does not do stealth scanning or evasion.
- it does not log into your router or scrape a router client list.
- it does not guarantee every device will show up, because sleepy wifi things, firewalls, guest networks, and client isolation are all real.

## quick start

install the latest release:

```sh
curl -fsSL https://raw.githubusercontent.com/RobertFlexx/lansentinel/main/scripts/install.sh | sh
```

if you are installing from a fork or a different repo path, set the repo explicitly:

```sh
curl -fsSL https://raw.githubusercontent.com/RobertFlexx/lansentinel/main/scripts/install.sh | LANSENTINEL_REPO=owner/repo sh
```

or build the binary if `ponyc` is on your `PATH`:

```sh
make build
```

if `ponyc` is installed somewhere custom, pass it explicitly:

```sh
make build PONYC="/path/to/ponyc"
```

scan a normal home `/24` with safe defaults:

```sh
./lansentinel --scan 192.168.1.0/24 --ports common
```

monitor a couple of services:

```sh
./lansentinel --name WebApp=localhost:7070 --name GameServer=localhost:25565
```

explain how discovery works before you scan:

```sh
./lansentinel --explain-scan
```

## terminal output

scan output looks like this:

```text
LanSentinel Scan

Range:
  192.168.1.0/24

Ports:
  22,80,443,7070,8080,25565

Scan mode:
  ARP-seeded TCP probes

Planned probes:
  24

Found 4 devices.

IP              Hostname       MAC               Vendor          Services
192.168.1.1     router.local    -                 -               80/http, 443/tcp
192.168.1.20    laptop.local    -                 -               22/ssh, 7070/http
192.168.1.42    media-box       -                 -               22/ssh
192.168.1.120   game-server     -                 -               25565/minecraft
```

watch output looks like this:

```text
LanSentinel 0.1.0   watching 3 targets   interval 5s   slow >500ms

Name         Target              Status   Latency   Avg    Up%     Checks
WebApp       localhost:7070      UP       4ms       6ms    100.0   42
Router       192.168.1.1:80      UP       7ms       9ms    100.0   42
GameServer   localhost:25565     DOWN     -         -      81.2    42
```

## discovery

scan a specific cidr range:

```sh
./lansentinel --scan 192.168.1.0/24 --ports common
./lansentinel --scan 10.0.0.0/24 --ports 22,80,443,7070,25565
```

use a router ip as a range hint:

```sh
./lansentinel --router 192.168.1.1
```

`--router` only assumes a likely `/24` range around that router address. it does not authenticate to the router and it does not read the router's connected-device list.

scan the guessed local lan range:

```sh
./lansentinel --scan-lan --ports common
```

`--scan-lan` reads the local linux route table and picks the subnet attached to your default route. if the detected range is not what you want, pass `--scan` directly. explicit is better here because every home network is a little weird.

lansentinel is not nmap. nmap can use raw arp and icmp host discovery, while lansentinel stays in normal userspace tcp checks plus local arp-cache observation. a device can show up in nmap but not have any of the selected tcp ports open. when that device is visible in your local arp cache, lansentinel now still reports it as an `arp-cache` device even if no service ports were found.

## scan modes

```sh
./lansentinel --scan 192.168.1.0/24 --scan-mode auto
./lansentinel --scan 192.168.1.0/24 --scan-mode arp
./lansentinel --scan 192.168.1.0/24 --scan-mode full --allow-large-scan
./lansentinel --scan 192.168.1.42 --deep-scan --ports common
```

- `auto` is the default. small ranges scan fully. larger ranges use arp-seeded tcp probes unless `--allow-large-scan` is provided.
- `arp` reports ips already visible in the local arp cache and inside the selected range.
- `full` probes every usable ip in the selected range. larger ranges require `--allow-large-scan` because full sweeps are noisy and easy to run by accident.
- `--deep-scan` is a shortcut for an intentional full sweep of the selected range.

`--scan` accepts either cidr notation or a single ipv4 address. a single address is treated as that address's `/24`, so `--scan 192.168.1.42` scans `192.168.1.0/24`.

more detail is in [`docs/scan-modes.md`](docs/scan-modes.md).

## service monitoring

watch plain tcp targets:

```sh
./lansentinel localhost:7070 192.168.1.1:80
./lansentinel --name WebApp=localhost:7070
```

watch simple `http://` targets:

```sh
./lansentinel --http http://localhost:7070
./lansentinel --http-name LocalWeb=http://localhost:7070
```

check once and return a failing exit code if anything is down:

```sh
./lansentinel --once --fail-fast localhost:1
```

use timing options when you want less chatty checks:

```sh
./lansentinel --interval 10s --timeout 2s --slow 750ms --name Router=192.168.1.1:80
```

## inventory

save inventory as json or csv:

```sh
./lansentinel --scan 192.168.1.0/24 --save inventory.json
./lansentinel --scan 192.168.1.0/24 --save inventory.csv
```

load inventory later:

```sh
./lansentinel --inventory inventory.json
```

turn discovered services into monitor targets:

```sh
./lansentinel --scan 192.168.1.0/24 --monitor-discovered
./lansentinel --inventory inventory.json --monitor-discovered
```

this is useful when you want to do one discovery pass, keep the result, and then watch the same devices without scanning every time.

## json output

print scan inventory as json:

```sh
./lansentinel --scan 127.0.0.0/30 --ports 1 --json
```

example:

```json
{"type":"inventory","range":"127.0.0.0/30","generated_at":"12:44:10","devices":[]}
```

one-shot monitor checks can also print json lines:

```sh
./lansentinel --once --json --name WebApp=localhost:7070
```

machine-readable output is kept plain on purpose, with no terminal clearing or table decoration mixed into it.

## prometheus output

```sh
./lansentinel --once --prometheus --name WebApp=localhost:7070
./lansentinel --scan 127.0.0.0/30 --ports 1 --prometheus
```

prometheus support is one-shot text output. it is not a long-running exporter server yet.

## config file

example config:

```text
interval = 5s
timeout = 2s
slow = 500ms
events = 10
log = lansentinel.log

target WebApp localhost:7070
target Router 192.168.1.1:80
target GameServer localhost:25565

http LocalWeb http://localhost:7070
```

run it:

```sh
./lansentinel --config examples/lansentinel.conf
```

the config format is intentionally boring. one setting per line, then `target` entries for tcp checks and `http` entries for simple http checks.

## useful cli options

```text
--scan <CIDR>                 scan a specific ipv4 cidr
--scan-lan                    scan a safely guessed local lan range
--router <IP>                 treat an ip as the router and scan a likely /24
--ports common|22,80,443      choose common lan ports or a comma list
--scan-mode auto|arp|full     choose scan planning behavior
--deep-scan                   full tcp sweep of the selected range
--allow-large-scan            allow large full scans
--save <path>                 save inventory as .json or .csv
--inventory <path>            load saved inventory
--monitor-discovered          monitor services from scan or inventory results
--name Name=host:port         add a named tcp target
--http-name Name=http://url   add a named simple http target
--once                        run checks once and exit
--watch                       watch continuously
--json                        print machine-readable json
--prometheus                  print one-shot prometheus text
--log <path>                  append state changes to a log file
```

run `./lansentinel --help` for the full list.

## build, test, and try locally

you need two things to build from source:

- `ponyc`, the pony compiler.
- a working native c/c++ toolchain, because `ponyc` still links a native executable at the end.

on linux, that usually means installing the normal compiler/linker package for your distro before running `make build`.

```sh
# debian / ubuntu
sudo apt install build-essential clang lld

# fedora
sudo dnf install gcc gcc-c++ clang lld compiler-rt

# arch
sudo pacman -S base-devel clang lld compiler-rt
```

build locally when `ponyc` is on your `PATH`:

```sh
make build
```

or point directly at a custom compiler path:

```sh
make build PONYC="/path/to/ponyc"
```

run the smoke tests:

```sh
scripts/smoke-test.sh
```

with a custom compiler path:

```sh
PONYC="/path/to/ponyc" scripts/smoke-test.sh
```

create a local distribution bundle if you want to inspect what would ship:

```sh
scripts/package.sh
```

the package script writes both a versioned archive and a stable platform archive, for example `lansentinel-v0.1.0-linux-x86_64.tar.gz` and `lansentinel-linux-x86_64.tar.gz`.

install the packaged binary into `~/.local/bin`:

```sh
scripts/install-local.sh
```

pony cross-compilation is not configured here, so the package script builds for the machine running it.

if the build reaches `Linking ./lansentinel` and then fails with something like `could not find compiler-rt CRT objects (crtbeginS.o) in lib paths`, the pony code already compiled. the system linker runtime is missing. install your distro's compiler toolchain package, usually `build-essential` on debian/ubuntu, `base-devel` on arch, or `gcc` plus `compiler-rt` on fedora-like systems.

more source-build help is in [`docs/building.md`](docs/building.md).

## safety

only scan networks you own or have permission to test.

lansentinel performs normal tcp connect probes and optional local arp cache enrichment. that is still network traffic, so use reasonable ranges, use the safe defaults first, and do not point it at networks where you do not belong.

more detail is in [`docs/safety.md`](docs/safety.md).

## limitations

- discovery is best-effort and cannot see every wifi device.
- sleeping devices, firewalls, guest networks, vlan boundaries, and client isolation can hide devices.
- arp-seeded mode can miss devices not already visible in the local arp cache.
- mac addresses are only available when visible through local arp cache data such as `/proc/net/arp` on linux.
- vendor lookup uses tiny built-in oui hints unless you provide a local oui file.
- reverse dns, mdns, and ssdp discovery are present as lightweight discovery helpers, not deep identity proof.
- https/tls deep inspection is not implemented.
- router admin client-list scraping/api support is not implemented.

## roadmap

- better local network inference for `--scan-lan`.
- richer reverse dns, mdns, and ssdp presentation.
- optional full oui database loading.
- deeper `http://` service identification.
- https/tls probing without pretending unsupported tls works.
- prometheus exporter/server mode.
- cleaner ctrl+c summary handling.
