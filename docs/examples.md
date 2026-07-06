# examples

these are copy-pasteable examples for common lansentinel workflows. replace the ip ranges and service names with your own network details.

## safe local test

use loopback when you want to check output formatting without touching the lan:

```sh
./lansentinel --scan 127.0.0.0/30 --ports 1 --json
```

this is also useful in ci because it does not depend on your router, wifi, or random devices being awake.

## scan a normal lan

```sh
./lansentinel --scan 192.168.1.0/24 --ports common
```

`common` checks the usual local-service ports. it is the easiest first pass when you just want to know what is visible.

## scan specific ports

```sh
./lansentinel --scan 192.168.1.0/24 --ports 22,80,443,7070,8080,25565
```

use this when you know the services you care about. fewer ports means fewer probes and usually a faster scan.

## use arp-seeded discovery

```sh
./lansentinel --scan 192.168.1.0/24 --scan-mode arp --ports common
```

this only probes addresses already visible in your local arp cache. it is conservative, but it can miss quiet devices.

## force a full tcp sweep

```sh
./lansentinel --scan 192.168.1.0/24 --scan-mode full --allow-large-scan --ports common
```

use this only on networks you own or have permission to test. full sweeps are louder because every usable address in the range gets probed.

## save and load inventory

```sh
./lansentinel --scan 192.168.1.0/24 --save inventory.json
./lansentinel --inventory inventory.json
```

csv output works too:

```sh
./lansentinel --scan 192.168.1.0/24 --save inventory.csv
```

## monitor discovered services

```sh
./lansentinel --inventory inventory.json --monitor-discovered
```

or do discovery and monitoring in one command:

```sh
./lansentinel --scan 192.168.1.0/24 --monitor-discovered
```

## monitor explicit tcp targets

```sh
./lansentinel --name WebApp=localhost:7070 --name Router=192.168.1.1:80
```

without names, plain `host:port` targets also work:

```sh
./lansentinel localhost:7070 192.168.1.1:80
```

## monitor simple http targets

```sh
./lansentinel --http-name LocalWeb=http://localhost:7070
```

only `http://` is supported for this simple check right now. https probing is intentionally not faked.

## one-shot health check for scripts

```sh
./lansentinel --once --fail-fast --name WebApp=localhost:7070
```

this exits non-zero when a target is down, which makes it handy for cron jobs, small deploy scripts, or smoke tests.

## prometheus text once

```sh
./lansentinel --once --prometheus --name WebApp=localhost:7070
```

this prints prometheus-style text once and exits. it is not a background exporter server.

## config file run

```sh
./lansentinel --config examples/lansentinel.conf
```

use the config file when a watch setup has enough targets or timing knobs that the cli command gets annoying.
