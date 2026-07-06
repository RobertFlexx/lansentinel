class val AppConfig
  let interval_ms: U64
  let timeout_ms: U64
  let slow_ms: U64
  let flap_window_ms: U64
  let flap_threshold: U64
  let once: Bool
  let json: Bool
  let prometheus: Bool
  let log_path: (String val | None)
  let no_clear: Bool
  let summary: Bool
  let events: USize
  let fail_fast: Bool
  let targets: Array[Target val] val
  let on_down: (String val | None)
  let on_up: (String val | None)
  let on_slow: (String val | None)
  let on_flap: (String val | None)
  let explain_scan: Bool
  let scan_lan: Bool
  let scan_cidr: (String val | None)
  let router_ip: (String val | None)
  let scan_ports: Array[U16] val
  let save_path: (String val | None)
  let inventory_path: (String val | None)
  let monitor_discovered: Bool
  let scan_timeout_ms: U64
  let scan_concurrency: USize
  let allow_large_scan: Bool
  let scan_mode: ScanMode
  let oui_file: (String val | None)
  let banner_read_ms: U64
  let discover_mdns: Bool
  let discover_ssdp: Bool
  let discover_revdns: Bool

  new val create(
    interval_ms': U64,
    timeout_ms': U64,
    slow_ms': U64,
    flap_window_ms': U64,
    flap_threshold': U64,
    once': Bool,
    json': Bool,
    prometheus': Bool,
    log_path': (String val | None),
    no_clear': Bool,
    summary': Bool,
    events': USize,
    fail_fast': Bool,
    targets': Array[Target val] val,
    on_down': (String val | None) = None,
    on_up': (String val | None) = None,
    on_slow': (String val | None) = None,
    on_flap': (String val | None) = None,
    explain_scan': Bool = false,
    scan_lan': Bool = false,
    scan_cidr': (String val | None) = None,
    router_ip': (String val | None) = None,
    scan_ports': Array[U16] val = recover val Array[U16] end,
    save_path': (String val | None) = None,
    inventory_path': (String val | None) = None,
    monitor_discovered': Bool = false,
    scan_timeout_ms': U64 = 500,
    scan_concurrency': USize = 64,
    allow_large_scan': Bool = false,
    scan_mode': ScanMode = ScanModeAuto,
    oui_file': (String val | None) = None,
    banner_read_ms': U64 = 2000,
    discover_mdns': Bool = true,
    discover_ssdp': Bool = true,
    discover_revdns': Bool = true)
  =>
    interval_ms = interval_ms'
    timeout_ms = timeout_ms'
    slow_ms = slow_ms'
    flap_window_ms = flap_window_ms'
    flap_threshold = flap_threshold'
    once = once'
    json = json'
    prometheus = prometheus'
    log_path = log_path'
    no_clear = no_clear'
    summary = summary'
    events = events'
    fail_fast = fail_fast'
    targets = targets'
    on_down = on_down'
    on_up = on_up'
    on_slow = on_slow'
    on_flap = on_flap'
    explain_scan = explain_scan'
    scan_lan = scan_lan'
    scan_cidr = scan_cidr'
    router_ip = router_ip'
    scan_ports = scan_ports'
    save_path = save_path'
    inventory_path = inventory_path'
    monitor_discovered = monitor_discovered'
    scan_timeout_ms = scan_timeout_ms'
    scan_concurrency = scan_concurrency'
    allow_large_scan = allow_large_scan'
    scan_mode = scan_mode'
    oui_file = oui_file'
    banner_read_ms = banner_read_ms'
    discover_mdns = discover_mdns'
    discover_ssdp = discover_ssdp'
    discover_revdns = discover_revdns'

  fun is_scan_mode(): Bool =>
    explain_scan or scan_lan or (scan_cidr isnt None) or (router_ip isnt None) or
      ((inventory_path isnt None) and not monitor_discovered)

  fun is_inventory_monitor_mode(): Bool =>
    (inventory_path isnt None) and monitor_discovered

primitive Version
  fun apply(): String val => "LanSentinel 0.2.0"
