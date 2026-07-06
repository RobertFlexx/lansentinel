use "signals"

actor Main
  new create(env: Env) =>
    match CliParser.parse(env)
    | let config: AppConfig val =>
      if config.explain_scan then
        env.out.print(ScanExplain())
      elseif config.is_inventory_monitor_mode() then
        _inventory_monitor(env, config)
      elseif config.inventory_path isnt None then
        _inventory_show(env, config)
      elseif config.scan_lan or (config.scan_cidr isnt None) or (config.router_ip isnt None) then
        _scan(env, config)
      else
        let shutdown = ShutdownHandler(env)
        let supervisor = Supervisor(env, config)
        shutdown.set_supervisor(supervisor)
        SignalHandler(ShutdownNotify(shutdown), Sig.int())
        SignalHandler(ShutdownNotify(shutdown), Sig.term())
        supervisor.start()
      end
    | let text: String val =>
      if (text == HelpText()) or (text == Version()) then
        env.out.print(text)
      else
        env.err.print(text)
        env.exitcode(2)
      end
    end

  fun _scan(env: Env, config: AppConfig val) =>
    let cidr_text: String val = match config.scan_cidr
    | let c: String val => c
    | None =>
      if config.scan_lan then
        match LocalNetwork.detect(env)
        | let r: CidrRange val =>
          if (not config.json) and (not config.prometheus) then
            env.out.print("Detected local LAN range:\n  " + r.string() + "\n\nUse --scan CIDR to override.\n")
          end
          r.string()
        | let err: String val => env.err.print(err); env.exitcode(2); return
        end
      else
        match config.router_ip
        | let ip: String val =>
          match CidrParser.from_router(ip)
          | let r: CidrRange val =>
            if (not config.json) and (not config.prometheus) then
              env.out.print("Router hint:\n  " + ip + "\n\nAssuming scan range:\n  " + r.string() + "\n\nUse --scan CIDR to override.\n")
              env.out.print("Tip:\n  If this finds nothing, check your real subnet with:\n    ip route show default\n    ip -o -4 addr show scope global\n")
            end
            r.string()
          | let err: String val => env.err.print(err); env.exitcode(2); return
          end
        | None =>
          env.err.print("Could not determine scan range. Pass --scan CIDR (e.g. --scan 192.168.1.0/24).")
          env.err.print("Tip:\n  Find your subnet with:\n    ip route show default\n    ip -o -4 addr show scope global")
          env.exitcode(2)
          return
        end
      end
    end
    match CidrParser.parse(cidr_text, config.allow_large_scan)
    | let r: CidrRange val =>
      match ScanModeValidator(r, config)
      | let err: String val => env.err.print(err); env.exitcode(2)
      | None => ScanSupervisor(env, config, r).start()
      end
    | let err: String val => env.err.print(err); env.exitcode(2)
    end

  fun _inventory_show(env: Env, config: AppConfig val) =>
    match config.inventory_path
    | let path: String val =>
      match InventoryJson.load(env, path)
      | let inv: InventoryData val =>
        if config.json then env.out.print(InventoryJson.render(inv)) else env.out.print(ScanRenderer.inventory_only(inv)) end
      | let err: String val => env.err.print(err); env.exitcode(2)
      end
    | None => env.err.print("Missing --inventory path"); env.exitcode(2)
    end

  fun _inventory_monitor(env: Env, config: AppConfig val) =>
    match config.inventory_path
    | let path: String val =>
      match InventoryJson.load(env, path)
      | let inv: InventoryData val =>
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
          env.err.print("No discovered services to monitor.")
          env.exitcode(1)
        else
          let cfg = AppConfig(config.interval_ms, config.timeout_ms, config.slow_ms,
            config.flap_window_ms, config.flap_threshold, false, config.json,
            config.prometheus, config.log_path, config.no_clear, config.summary,
            config.events, config.fail_fast, consume targets, config.on_down,
            config.on_up, config.on_slow, config.on_flap)
          Supervisor(env, cfg).start()
        end
      | let err: String val => env.err.print(err); env.exitcode(2)
      end
    | None => env.err.print("Missing --inventory path"); env.exitcode(2)
    end

actor ShutdownHandler
  let _env: Env
  var _supervisor: (Supervisor tag | None) = None

  new create(env: Env) =>
    _env = env

  be set_supervisor(s: Supervisor tag) =>
    _supervisor = s

  be shutdown() =>
    _env.out.print("Shutting down...")
    match _supervisor
    | let s: Supervisor tag => s.stop()
    | None => _env.exitcode(0)
    end

class ShutdownNotify is SignalNotify
  let _handler: ShutdownHandler tag

  new iso create(handler: ShutdownHandler tag) =>
    _handler = handler

  fun ref apply(count: U32): Bool =>
    _handler.shutdown()
    true
