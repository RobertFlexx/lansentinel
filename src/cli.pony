use "collections"

primitive HelpText
  fun apply(): String val =>
    "LanSentinel - LAN discovery and service monitoring utility\n\n" +
    "Usage:\n" +
    "  lansentinel [options] <host:port>...\n" +
    "  lansentinel --scan 192.168.1.0/24 [options]\n" +
    "  lansentinel --router 192.168.1.1 [options]\n" +
    "  lansentinel --inventory inventory.json [--monitor-discovered]\n\n" +
    "Monitoring:\n" +
    "  --interval <duration>  Check interval, default 5s\n" +
    "  --timeout <duration>   TCP timeout hint, default 2s\n" +
    "  --slow <duration>      Slow threshold, default 500ms\n" +
    "  --name <Name=host:port> Add a named TCP target\n" +
    "  --http <url>           Add a simple HTTP target, http:// only\n" +
    "  --http-name <Name=url> Add a named HTTP target, http:// only\n" +
    "  --config <path>        Read simple LanSentinel config\n" +
    "  --once                 Check once, print results, then exit\n" +
    "  --watch                Explicit watch mode, default unless --once\n" +
    "  --summary              Print summary in --once mode\n" +
    "  --events <number>      Recent event count, default 10\n" +
    "  --fail-fast            Exit 1 in --once mode if any target is down\n" +
    "  --flap-window <duration>  Flap window, default 1m\n" +
    "  --flap-threshold <number> Flap changes threshold, default 3\n\n" +
    "Discovery:\n" +
    "  --scan-lan             Scan a safely guessed local LAN range\n" +
    "  --scan <CIDR>          Scan a specific IPv4 CIDR\n" +
    "  --deep-scan            Full TCP sweep of the selected range\n" +
    "  --router <IP>          Treat IP as router and scan likely /24\n" +
    "  --ports common|list    Common LAN ports or comma-separated ports\n" +
    "  --save <path>          Save inventory as JSON or CSV\n" +
    "  --inventory <path>     Load saved inventory\n" +
    "  --monitor-discovered   Monitor services from scan or inventory\n" +
    "  --scan-timeout <dur>   Timeout per probe, default 500ms\n" +
    "  --banner-timeout <dur> Banner read timeout, default 2s (0 to disable)\n" +
    "  --scan-concurrency <n> Max active probes, default 64\n" +
    "  --scan-mode auto|arp|full  Scan planning mode, default auto\n" +
    "  --allow-large-scan     Allow ranges larger than /24\n" +
    "  --oui-file <path>      Optional local OUI/vendor file\n" +
    "  --no-mdns              Disable mDNS/Bonjour discovery\n" +
    "  --no-ssdp              Disable SSDP/UPnP discovery\n" +
    "  --no-revdns            Disable reverse DNS lookup\n" +
    "  --explain-scan         Explain discovery methods and limits\n\n" +
    "Output:\n" +
    "  --json                 Print JSON lines / inventory JSON\n" +
    "  --prometheus           Print Prometheus text in --once mode\n" +
    "  --log <path>           Append state transitions to a log file\n" +
    "  --no-clear             Do not clear terminal between refreshes\n" +
    "  --help                 Print this help text\n" +
    "  --version              Print version\n"

primitive CliParser
  fun parse(env: Env): (AppConfig val | String val) =>
    let args = env.args
    var interval_ms: U64 = 5000
    var timeout_ms: U64 = 2000
    var slow_ms: U64 = 500
    var flap_window_ms: U64 = 60000
    var flap_threshold: U64 = 3
    var once = false
    var json = false
    var prometheus = false
    var no_clear = false
    var summary = false
    var events: USize = 10
    var fail_fast = false
    var log_path: (String val | None) = None
    var on_down: (String val | None) = None
    var on_up: (String val | None) = None
    var on_slow: (String val | None) = None
    var on_flap: (String val | None) = None
    var explain_scan = false
    var scan_lan = false
    var scan_cidr: (String val | None) = None
    var router_ip: (String val | None) = None
    let scan_ports = recover trn Array[U16] end
    var save_path: (String val | None) = None
    var inventory_path: (String val | None) = None
    var monitor_discovered = false
    var scan_timeout_ms: U64 = 500
    var scan_concurrency: USize = 64
    var allow_large_scan = false
    var scan_mode_value: ScanMode = ScanModeAuto
    var oui_file: (String val | None) = None
    var banner_read_ms: U64 = 2000
    var discover_mdns = true
    var discover_ssdp = true
    var discover_revdns = true
    let targets = recover trn Array[Target val] end

    try
      var i: USize = 1
      while i < args.size() do
        let arg = args(i)?
        match arg
        | "--help" => return HelpText()
        | "--version" => return Version()
        | "--once" => once = true
        | "--watch" => once = false
        | "--json" => json = true
        | "--prometheus" => prometheus = true
        | "--no-clear" => no_clear = true
        | "--summary" => summary = true
        | "--fail-fast" => fail_fast = true
        | "--allow-large-scan" => allow_large_scan = true
        | "--deep-scan" => scan_mode_value = ScanModeFull; allow_large_scan = true
        | "--scan-lan" => scan_lan = true
        | "--monitor-discovered" => monitor_discovered = true
        | "--explain-scan" => explain_scan = true
        | "--no-mdns" => discover_mdns = false
        | "--no-ssdp" => discover_ssdp = false
        | "--no-revdns" => discover_revdns = false
        | "--interval" =>
          i = i + 1
          if i >= args.size() then return "Missing value for --interval" end
          match DurationParser.parse(args(i)?) | let ms: U64 => interval_ms = ms | let err: String val => return err end
        | "--timeout" =>
          i = i + 1
          if i >= args.size() then return "Missing value for --timeout" end
          match DurationParser.parse(args(i)?) | let ms: U64 => timeout_ms = ms | let err: String val => return err end
        | "--slow" =>
          i = i + 1
          if i >= args.size() then return "Missing value for --slow" end
          match DurationParser.parse(args(i)?) | let ms: U64 => slow_ms = ms | let err: String val => return err end
        | "--log" => i = _need_arg(args, i, "--log")?; log_path = args(i)?
        | "--events" => i = _need_arg(args, i, "--events")?; events = args(i)?.usize()?
        | "--flap-window" =>
          i = _need_arg(args, i, "--flap-window")?
          match DurationParser.parse(args(i)?) | let ms: U64 => flap_window_ms = ms | let err: String val => return err end
        | "--flap-threshold" => i = _need_arg(args, i, "--flap-threshold")?; flap_threshold = args(i)?.u64()?
        | "--name" =>
          i = _need_arg(args, i, "--name")?
          match TargetParser.parse_named(args(i)?) | let t: Target val => targets.push(t) | let err: String val => return err end
        | "--http" =>
          i = _need_arg(args, i, "--http")?
          match TargetParser.parse_http(args(i)?) | let t: Target val => targets.push(t) | let err: String val => return err end
        | "--http-name" =>
          i = _need_arg(args, i, "--http-name")?
          match TargetParser.parse_http(args(i)?, true) | let t: Target val => targets.push(t) | let err: String val => return err end
        | "--config" =>
          i = _need_arg(args, i, "--config")?
          match ConfigFileParser.parse(env, args(i)?)
          | let c: ConfigFileData val =>
            match c.interval_ms | let v: U64 => interval_ms = v | None => None end
            match c.timeout_ms | let v: U64 => timeout_ms = v | None => None end
            match c.slow_ms | let v: U64 => slow_ms = v | None => None end
            match c.flap_window_ms | let v: U64 => flap_window_ms = v | None => None end
            match c.flap_threshold | let v: U64 => flap_threshold = v | None => None end
            match c.events | let v: USize => events = v | None => None end
            log_path = c.log_path; on_down = c.on_down; on_up = c.on_up; on_slow = c.on_slow; on_flap = c.on_flap
            for t in c.targets.values() do targets.push(t) end
          | let err: String val => return err
          end
        | "--on-down" => i = _need_arg(args, i, "--on-down")?; on_down = args(i)?
        | "--on-up" => i = _need_arg(args, i, "--on-up")?; on_up = args(i)?
        | "--on-slow" => i = _need_arg(args, i, "--on-slow")?; on_slow = args(i)?
        | "--on-flap" => i = _need_arg(args, i, "--on-flap")?; on_flap = args(i)?
        | "--scan" => i = _need_arg(args, i, "--scan")?; scan_cidr = args(i)?
        | "--router" => i = _need_arg(args, i, "--router")?; router_ip = args(i)?
        | "--ports" =>
          i = _need_arg(args, i, "--ports")?
          match PortListParser.parse(args(i)?)
          | let ports: Array[U16] val => for p in ports.values() do scan_ports.push(p) end
          | let err: String val => return err
          end
        | "--save" => i = _need_arg(args, i, "--save")?; save_path = args(i)?
        | "--inventory" => i = _need_arg(args, i, "--inventory")?; inventory_path = args(i)?
        | "--scan-timeout" =>
          i = _need_arg(args, i, "--scan-timeout")?
          match DurationParser.parse(args(i)?) | let ms: U64 => scan_timeout_ms = ms | let err: String val => return err end
        | "--banner-timeout" =>
          i = _need_arg(args, i, "--banner-timeout")?
          match DurationParser.parse(args(i)?) | let ms: U64 => banner_read_ms = ms | let err: String val => return err end
        | "--scan-concurrency" =>
          i = _need_arg(args, i, "--scan-concurrency")?
          scan_concurrency = args(i)?.usize()?
          if scan_concurrency == 0 then return "--scan-concurrency must be greater than 0" end
        | "--scan-mode" =>
          i = _need_arg(args, i, "--scan-mode")?
          match ScanModeParser.parse(args(i)?)
          | let mode: ScanMode => scan_mode_value = mode
          | let err: String val => return err
          end
        | "--oui-file" => i = _need_arg(args, i, "--oui-file")?; oui_file = args(i)?
        else
          if (arg.size() >= 2) and (arg.substring(0, 2) == "--") then
            return "Unknown option: " + arg + "\n\n" + HelpText()
          end
          match TargetParser.parse(arg) | let t: Target val => targets.push(t) | let err: String val => return err end
        end
        i = i + 1
      end
    else
      return "Invalid command line.\n\n" + HelpText()
    end

    let scan_mode = explain_scan or scan_lan or (scan_cidr isnt None) or (router_ip isnt None) or (inventory_path isnt None)
    if (targets.size() == 0) and not scan_mode then return "No targets provided.\n\n" + HelpText() end
    if json and prometheus then return "--json and --prometheus are mutually exclusive." end
    if (scan_cidr isnt None) and scan_lan then return "Use either --scan-lan or --scan CIDR, not both." end

    let scan_ports_val: Array[U16] val = if scan_ports.size() == 0 then CommonPorts() else consume scan_ports end

    AppConfig(interval_ms, timeout_ms, slow_ms, flap_window_ms, flap_threshold,
      once, json, prometheus, log_path, no_clear, summary, events, fail_fast,
      consume targets, on_down, on_up, on_slow, on_flap, explain_scan,
      scan_lan, scan_cidr, router_ip, scan_ports_val, save_path,
      inventory_path, monitor_discovered, scan_timeout_ms, scan_concurrency,
      allow_large_scan, scan_mode_value, oui_file, banner_read_ms,
      discover_mdns, discover_ssdp, discover_revdns)

  fun _need_arg(args: Array[String val] val, i: USize, name: String val): USize ? =>
    let next = i + 1
    if next >= args.size() then error end
    next

primitive CommonPorts
  fun apply(): Array[U16] val =>
    recover val
      [as U16: 22; 53; 80; 139; 443; 445; 631; 1883; 3000; 5000; 5357; 7070; 8000; 8080; 8123; 8443; 9000; 25565]
    end

primitive PortListParser
  fun parse(input: String val): (Array[U16] val | String val) =>
    if input == "common" then return CommonPorts() end
    let ports = recover trn Array[U16] end
    var rest: String val = input
    try
      while rest.size() > 0 do
        try
          let comma = rest.find(",")?
          let part_iso = rest.substring(0, comma.isize())
          let part: String val = consume part_iso
          let p = part.u64()?
          if (p < 1) or (p > 65535) then error end
          ports.push(p.u16())
          let next_iso = rest.substring((comma + 1).isize())
          rest = consume next_iso
        else
          let p = rest.u64()?
          if (p < 1) or (p > 65535) then error end
          ports.push(p.u16())
          rest = ""
        end
      end
    else
      return "Invalid --ports value: " + input + "\n\nUse:\n  --ports common\n  --ports 22,80,443,7070"
    end
    if ports.size() == 0 then "Invalid --ports value: " + input else consume ports end
