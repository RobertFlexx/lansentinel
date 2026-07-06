use "net"
use "time"
use "collections"

class val ScanProbe
  let id: U64
  let ip: String val
  let port: U16

  new val create(id': U64, ip': String val, port': U16) =>
    id = id'
    ip = ip'
    port = port'

actor ScanSupervisor is (MdnsHandler & SsdpHandler & RevDnsHandler)
  let _env: Env
  let _config: AppConfig val
  let _range: CidrRange val
  let _probes: Array[ScanProbe val] val
  let _actual_mode: ScanMode
  let _devices: Map[String val, DeviceBuilder] = Map[String val, DeviceBuilder]
  let _pending: Map[U64, ScanProbe val] = Map[U64, ScanProbe val]
  var _timers: Timers = Timers
  var _next: USize = 0
  var _active: USize = 0
  var _done: USize = 0
  var _open_services: USize = 0
  var _finished: Bool = false
  let _mdns_names: Map[String val, String val] = Map[String val, String val]
  let _mdns_svcs: Map[String val, Array[String val] val] = Map[String val, Array[String val] val]
  let _ssdp_devices: Map[String val, SsdpDevice val] = Map[String val, SsdpDevice val]
  let _revdns_names: Map[String val, String val] = Map[String val, String val]

  new create(env: Env, config: AppConfig val, range: CidrRange val) =>
    _env = env
    _config = config
    _range = range
    _actual_mode = EffectiveScanMode(range, config)
    _probes = ScanProbeBuilder(range, config.scan_ports, ArpCache.read(env), _actual_mode)

  be start() =>
    if (not _config.json) and (not _config.prometheus) then
      _env.out.print("LanSentinel Scan\n")
      _env.out.print("Range:\n  " + _range.string() + "\n")
      _env.out.print("Ports:\n  " + _ports_text() + "\n")
      _env.out.print("Scan mode:\n  " + ScanModeText.title(_actual_mode) + "\n")
      if _actual_mode is ScanModeArp then
        _env.out.print("This range has more than 32 hosts, so LanSentinel is probing only devices already visible in the local ARP cache.\n")
        _env.out.print("\nFor a full TCP sweep, run again with:\n  --allow-large-scan\n")
      end
      _env.out.print("\nPlanned probes:\n  " + _probes.size().string() + "\n")
      _env.out.print("Concurrency:\n  " + _config.scan_concurrency.string() + "\n")
      _env.out.print("Timeout:\n  " + (_config.scan_timeout_ms + _config.banner_read_ms).string() + "ms")
      if _config.banner_read_ms > 0 then
        _env.out.print("  (connect " + _config.scan_timeout_ms.string() + "ms + banner " + _config.banner_read_ms.string() + "ms)")
      end
      _env.out.print("\nProgress:")
      if (_actual_mode is ScanModeArp) and (_probes.size() == 0) then
        _print_zero_probe_hint()
      end
    end
    if _config.discover_mdns then MdnsProbe(_env, this).start() end
    if _config.discover_ssdp then SsdpProbe(_env, this).start() end
    _fill()

  fun _print_zero_probe_hint() =>
    _env.out.print("\nNo ARP-cache devices found inside " + _range.string() + ".\n")
    _env.out.print("ARP-seeded mode only probes devices already visible in this computer's ARP cache.")
    _env.out.print("This can happen if:")
    _env.out.print("  - the selected subnet is wrong")
    _env.out.print("  - no devices have recently talked to this computer")
    _env.out.print("  - the ARP cache is empty")
    _env.out.print("  - devices are asleep, firewalled, or isolated")
    match _config.router_ip
    | let ip: String val =>
      _env.out.print("  - " + ip + " is not the real gateway for this network")
    | None => None
    end
    _env.out.print("\nTry:")
    _env.out.print("  ip route show default")
    _env.out.print("  ip -o -4 addr show scope global")
    _env.out.print("  cat /proc/net/arp")
    _env.out.print("\nOr run a full sweep:")
    _env.out.print("  lansentinel --scan " + _range.string() + " --scan-mode full --allow-large-scan --ports common")

  fun _ports_text(): String val =>
    let out = recover trn String end
    var first = true
    for p in _config.scan_ports.values() do
      if not first then out.append(",") end
      first = false
      out.append(p.string())
    end
    consume out

  fun ref _fill() =>
    try
      while (_active < _config.scan_concurrency) and (_next < _probes.size()) do
        let p = _probes(_next)?
        _next = _next + 1
        _active = _active + 1
        _pending(p.id) = p
        let conn = TCPConnection(TCPConnectAuth(_env.root), ScanNotify(this, p, Clock.epoch_ms()), p.ip, p.port.string())
        let total_timeout = (_config.scan_timeout_ms + _config.banner_read_ms) * 1000000
        let timer = Timer(ScanTimeout(this, p, conn), total_timeout)
        _timers(consume timer)
      end
    end
    if (_done >= _probes.size()) and (_active == 0) and not _finished then _finish() end

  be mdns_results(ips: Map[String val, String val] val, services: Map[String val, Array[String val] val] val) =>
    for (ip, hn) in ips.pairs() do
      _mdns_names(ip) = hn
    end
    for (ip, svcs) in services.pairs() do
      _mdns_svcs(ip) = svcs
    end

  be ssdp_results(devices: Map[String val, SsdpDevice val] val) =>
    for (ip, d) in devices.pairs() do
      _ssdp_devices(ip) = d
    end

  be revdns_results(names: Map[String val, String val] val) =>
    for (ip, name) in names.pairs() do
      _revdns_names(ip) = name
    end

  be probe_done(probe: ScanProbe val, open: Bool, latency_ms: U64, banner: String val) =>
    if _finished then return end
    try
      _pending.remove(probe.id)?
    else
      return
    end
    if _active > 0 then _active = _active - 1 end
    _done = _done + 1
    if open then
      _open_services = _open_services + 1
      let builder = try _devices(probe.ip)? else
        let b = DeviceBuilder(probe.ip)
        _devices(probe.ip) = b
        b
      end
      let proto = ServiceNames.protocol(probe.port)
      let b: (String val | None) = if banner.size() > 0 then banner else None end
      builder.add_service(ServiceInfo(probe.port, proto, "open", latency_ms, b), Clock.time_of_day())
    end
    if (not _config.json) and (not _config.prometheus) and ((_done % 64) == 0) then
      _env.out.print("  Probes checked: " + _done.string() + " / " + _probes.size().string() +
        "   Devices found: " + _devices.size().string() + "   Open services: " + _open_services.string())
    end
    _fill()

  fun ref _finish() =>
    _finished = true
    _merge_discoveries()
    let arp = ArpCache.read(_env)
    let devices = recover trn Array[DeviceInfo val] end
    for b in _devices.values() do
      try
        let mac = arp(b.ip)?
        b.mac = mac
        b.vendor = VendorLookup(mac)
      end
      if not _config.json and not _config.prometheus then
        _env.out.print("  mDNS hostname for " + b.ip + ": " + _mdns_names.get_or_else(b.ip, "-"))
      end
      devices.push(b.snapshot())
    end
    let methods = recover trn Array[String val] end
    methods.push("tcp-connect (" + _probes.size().string() + " probes)")
    if _config.banner_read_ms > 0 then methods.push("banner-read (" + _config.banner_read_ms.string() + "ms)") end
    if _config.discover_mdns then methods.push("mDNS") end
    if _config.discover_ssdp then methods.push("SSDP") end
    if _config.discover_revdns then methods.push("reverse-DNS") end
    let inv = InventoryData(_range.string(), consume devices, Clock.time_of_day(), consume methods)
    var saved_path: (String val | None) = None
    var save_failed = false
    match _config.save_path
    | let path: String val =>
      let saved = if _ends_with(path, ".csv") then InventoryCsv.save(_env, path, inv) else InventoryJson.save(_env, path, inv) end
      if saved then
        saved_path = path
      else
        save_failed = true
        _env.err.print("Error: could not save inventory: " + path)
      end
    | None => None
    end
    if _config.json then
      _env.out.print(InventoryJson.render(inv))
      if save_failed then _env.exitcode(3) else _env.exitcode(0) end
    elseif _config.prometheus then
      _env.out.print(ScanPrometheus(inv))
      if save_failed then _env.exitcode(3) else _env.exitcode(0) end
    elseif _config.monitor_discovered then
      _start_monitoring(inv)
    else
      _env.out.print("  Probes checked: " + _done.string() + " / " + _probes.size().string())
      _env.out.print(ScanRenderer.completion(inv, _open_services, saved_path))
      _env.out.print(ScanRenderer.human(inv))
      if save_failed then _env.exitcode(3) else _env.exitcode(0) end
    end
    if _config.discover_revdns and (_revdns_names.size() == 0) then
      RevDnsProbe(_env, this, _get_all_ips()).start()
    end

  fun ref _merge_discoveries() =>
    for (ip, hn) in _mdns_names.pairs() do
      try
        if not _devices.contains(ip) then
          _devices(ip) = DeviceBuilder(ip)
        end
        let d = _devices(ip)?
        if d.hostname is None then d.hostname = hn end
        d.add_tag("mDNS")
      end
    end
    for (ip, d) in _ssdp_devices.pairs() do
      try
        if not _devices.contains(ip) then
          _devices(ip) = DeviceBuilder(ip)
        end
        let b = _devices(ip)?
        b.add_tag("SSDP")
        match d.server
        | let s: String val =>
          let os = _extract_os_from_server(s)
          if os.size() > 0 then
            b.add_service(ServiceInfo(0, "upnp", "open", None, None, None, None, None, os), Clock.time_of_day())
          end
        | None => None
        end
      end
    end
    for (ip, name) in _revdns_names.pairs() do
      try
        if not _devices.contains(ip) then
          _devices(ip) = DeviceBuilder(ip)
        end
        let d = _devices(ip)?
        if d.hostname is None then d.hostname = name end
        d.add_tag("reverse-dns")
      end
    end

  fun _extract_os_from_server(server: String val): String val =>
    try
      if server.find("Linux", 0)? >= 0 then "linux"
      elseif server.find("Windows", 0)? >= 0 then "windows"
      elseif server.find("Darwin", 0)? >= 0 then "macos"
      elseif server.find("FreeBSD", 0)? >= 0 then "freebsd"
      elseif server.find("Android", 0)? >= 0 then "android"
      elseif server.find("iOS", 0)? >= 0 then "ios"
      else ""
      end
    else
      ""
    end

  fun _get_all_ips(): Array[String val] val =>
    let out = recover trn Array[String val] end
    for ip in _devices.keys() do
      out.push(ip)
    end
    consume out

  fun ref _start_monitoring(inv: InventoryData val) =>
    let targets = recover trn Array[Target val] end
    for d in inv.devices.values() do
      for s in d.services.values() do
        let name_iso = d.ip + ":" + s.port.string()
        let name: String val = consume name_iso
        if s.protocol == "http" then
          targets.push(Target(name, d.ip, s.port, CheckHTTP, "/"))
        else
          targets.push(Target(name, d.ip, s.port))
        end
      end
    end
    if targets.size() == 0 then
      _env.err.print("No discovered services to monitor.")
      _env.exitcode(1)
    else
      let cfg = AppConfig(_config.interval_ms, _config.timeout_ms, _config.slow_ms,
        _config.flap_window_ms, _config.flap_threshold, false, _config.json,
        _config.prometheus, _config.log_path, _config.no_clear, _config.summary,
        _config.events, _config.fail_fast, consume targets, _config.on_down,
        _config.on_up, _config.on_slow, _config.on_flap)
      Supervisor(_env, cfg).start()
    end

  fun _ends_with(s: String val, suffix: String val): Bool =>
    (s.size() >= suffix.size()) and (s.substring((s.size() - suffix.size()).isize()) == suffix)

class iso ScanNotify is TCPConnectionNotify
  let _supervisor: ScanSupervisor
  let _probe: ScanProbe val
  let _start_ms: U64
  var _reported: Bool = false
  var _connected: Bool = false
  var _banner: String val = ""

  new iso create(supervisor: ScanSupervisor, probe: ScanProbe val, start_ms: U64) =>
    _supervisor = supervisor
    _probe = probe
    _start_ms = start_ms

  fun ref connected(conn: TCPConnection ref) =>
    _connected = true

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize): Bool =>
    if _reported then return false end
    let text = String.from_array(consume data)
    _banner = recover val _banner + text end
    if _banner.size() >= 4096 then
      _reported = true
      _supervisor.probe_done(_probe, true, Clock.epoch_ms() - _start_ms, _banner)
      conn.close()
      return false
    end
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    if not _reported then
      _reported = true
      _supervisor.probe_done(_probe, false, 0, "")
    end

  fun ref closed(conn: TCPConnection ref) =>
    if _reported then return end
    _reported = true
    if _connected then
      _supervisor.probe_done(_probe, true, Clock.epoch_ms() - _start_ms, _banner)
    else
      _supervisor.probe_done(_probe, false, 0, "")
    end

class iso ScanTimeout is TimerNotify
  let _supervisor: ScanSupervisor
  let _probe: ScanProbe val
  let _conn: TCPConnection

  new iso create(supervisor: ScanSupervisor, probe: ScanProbe val, conn: TCPConnection) =>
    _supervisor = supervisor
    _probe = probe
    _conn = conn

  fun ref apply(timer: Timer, count: U64): Bool =>
    _conn.dispose()
    _supervisor.probe_done(_probe, false, 0, "")
    false

primitive ScanPrometheus
  fun apply(inv: InventoryData val): String val =>
    let out = recover trn String end
    out.append("# HELP lansentinel_scan_devices_found Number of devices discovered.\n")
    out.append("# TYPE lansentinel_scan_devices_found gauge\n")
    out.append("lansentinel_scan_devices_found{range=\"" + Json.esc(inv.range) + "\"} " + inv.devices.size().string() + "\n")
    consume out

primitive ScanProbeBuilder
  fun apply(range: CidrRange val, ports: Array[U16] val, arp: Map[String val, String val] box, mode: ScanMode): Array[ScanProbe val] val =>
    let out = recover trn Array[ScanProbe val] end
    var id: U64 = 1
    let hosts: Array[String val] val = if mode is ScanModeFull then
      range.hosts()
    else
      let seeded = recover trn Array[String val] end
      for ip in arp.keys() do
        if range.contains(ip) then seeded.push(ip) end
      end
      consume seeded
    end
    for ip in hosts.values() do
      for p in ports.values() do
        out.push(ScanProbe(id, ip, p))
        id = id + 1
      end
    end
    consume out

primitive EffectiveScanMode
  fun apply(range: CidrRange val, config: AppConfig val): ScanMode =>
    match config.scan_mode
    | ScanModeArp => ScanModeArp
    | ScanModeFull => ScanModeFull
    | ScanModeAuto =>
      if (range.host_count() <= 32) or config.allow_large_scan then ScanModeFull else ScanModeArp end
    end

primitive ScanModeValidator
  fun apply(range: CidrRange val, config: AppConfig val): (None | String val) =>
    if (config.scan_mode is ScanModeFull) and (range.host_count() > 32) and (not config.allow_large_scan) then
      "Refusing full scan of " + range.string() + " without --allow-large-scan.\n\n" +
      "Use:\n  ./lansentinel --scan " + range.string() + " --scan-mode full --allow-large-scan"
    else
      None
    end
