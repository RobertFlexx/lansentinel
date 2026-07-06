primitive ScanExplain
  fun apply(): String val =>
    "LanSentinel LAN discovery\n\n" +
    "Methods used:\n" +
    "  - TCP connect probes to selected ports.\n" +
    "  - Optional Linux ARP cache enrichment when available.\n" +
    "  - Banner reading on successful connections.\n" +
    "  - mDNS/Bonjour discovery for Apple, printer, IoT devices.\n" +
    "  - SSDP/UPnP discovery for media, smart home devices.\n" +
    "  - Reverse DNS for hostname resolution.\n" +
    "  - Lightweight service labeling from known port numbers.\n\n" +
    "Scan modes:\n" +
    "  auto: small ranges scan fully; larger ranges use ARP-seeded probes unless --allow-large-scan is provided.\n" +
    "  arp: only probe IPs already visible in the local ARP cache and inside the selected range.\n" +
    "  full: probe every usable IP in the selected range; large ranges require --allow-large-scan.\n\n" +
    "ARP-seeded mode can miss devices that are not already known to this host. It is quiet, fast, and pure Pony lifecycle-friendly.\n\n" +
    "Full TCP sweep can discover more devices, but it is slower, noisier, and can create many simultaneous TCP connect attempts. Use it only on networks you own or have permission to test.\n\n" +
    "To force a full sweep safely:\n" +
    "  ./lansentinel --scan 192.168.1.0/24 --scan-mode full --allow-large-scan\n\n" +
    "Router hints:\n" +
    "  --router 192.168.1.1 assumes a likely /24 range. It does not log into the router or read its client list. Router IP alone does not reveal every client.\n\n" +
    "What is collected:\n" +
    "  - IP addresses that respond on scanned TCP ports.\n" +
    "  - Open ports and simple service labels.\n" +
    "  - Service banners from TCP connections.\n" +
    "  - mDNS/SSDP multicast advertisements.\n" +
    "  - DNS-based reverse hostnames.\n" +
    "  - MAC/vendor only when available locally, such as ARP cache data.\n\n" +
    "What is not collected:\n" +
    "  - Passwords, credentials, packet captures, or vulnerability data.\n" +
    "  - Router admin client lists.\n" +
    "  - TLS/SSL deep inspection.\n\n" +
    "Limitations:\n" +
    "  LanSentinel performs best-effort LAN discovery. Some devices may not appear if they are asleep, firewalled, on a guest network, behind client isolation, or not responding to probes.\n\n" +
    "  Some Wi-Fi clients intentionally ignore inbound probes or are hidden by AP/client isolation.\n\n" +
    "Safety:\n" +
    "  Only scan networks you own or have permission to test.\n"

primitive ScanRenderer
  fun completion(inv: InventoryData val, open_services: USize, saved_path: (String val | None)): String val =>
    let out = recover trn String end
    out.append("\nScan complete.\n\n")
    out.append("Found:\n")
    out.append("  " + inv.devices.size().string() + " devices\n")
    out.append("  " + open_services.string() + " open services\n")
    match saved_path
    | let path: String val =>
      out.append("\nSaved inventory:\n")
      out.append("  " + path + "\n")
    | None => None
    end
    if inv.discovery_methods.size() > 0 then
      out.append("\nDiscovery methods:\n")
      for m in inv.discovery_methods.values() do
        out.append("  - " + m + "\n")
      end
    end
    out.append("\n")
    consume out

  fun human(inv: InventoryData val): String val =>
    let out = recover trn String end
    out.append("LanSentinel Network Scan\n\n")
    out.append("Range:\n  " + inv.range + "\n\n")
    out.append("Found " + inv.devices.size().string() + " devices.\n\n")
    out.append("IP              Hostname       MAC               Vendor          Services\n")
    for d in inv.devices.values() do
      out.append(_pad(d.ip, 15) + " ")
      out.append(_pad(_opt(d.hostname), 14) + " ")
      out.append(_pad(_opt(d.mac), 17) + " ")
      out.append(_pad(_opt(d.vendor), 15) + " ")
      out.append(_services(d) + "\n")
      for s in d.services.values() do
        match s.banner
        | let b: String val =>
          let first_line = _first_line(b)
          if first_line.size() > 0 then
            out.append("  " + _pad("", 15) + " " + _pad("", 14) + " " + _pad("", 17) + " " +
              _pad("", 15) + " banner: " + first_line + "\n")
          end
        | None => None
        end
      end
      if d.discovery_tags.size() > 0 then
        out.append("  " + _pad("", 15) + " " + _pad("", 14) + " " + _pad("", 17) + " " +
          _pad("", 15) + " tags: ")
        var first = true
        for t in d.discovery_tags.values() do
          if not first then out.append(", ") end
          first = false
          out.append(t)
        end
        out.append("\n")
      end
    end
    out.append("\nTip:\n  Start monitoring discovered services with:\n    ./lansentinel --monitor-discovered --inventory inventory.json\n")
    consume out

  fun inventory_only(inv: InventoryData val): String val => human(inv)

  fun _services(d: DeviceInfo val): String val =>
    let out = recover trn String end
    var first = true
    for s in d.services.values() do
      if not first then out.append(", ") end
      first = false
      out.append(s.port.string() + "/" + s.protocol)
      match s.os_hint
      | let os: String val => out.append("[" + os + "]")
      | None => None
      end
    end
    if first then out.append("-") end
    consume out

  fun _opt(v: (String val | None)): String val => match v | let s: String val => s | None => "-" end

  fun _pad(s: String val, width: USize): String val =>
    let out = recover trn String end
    out.append(s)
    var i = s.size()
    while i < width do out.push(' '); i = i + 1 end
    consume out

  fun _first_line(s: String val): String val =>
    try
      let nl = s.find("\n")?
      if nl > 0 then s.substring(0, nl.isize()) else s end
    else
      s
    end
