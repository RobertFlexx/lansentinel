use "process"
use "backpressure"
use "files"

class val HookConfig
  let cmd: String val
  let event_for: String val

  new val create(cmd': String val, event_for': String val) =>
    cmd = cmd'
    event_for = event_for'

actor HookRunner
  let _env: Env
  let _on_down: (HookConfig val | None)
  let _on_up: (HookConfig val | None)
  let _on_slow: (HookConfig val | None)
  let _on_flap: (HookConfig val | None)
  let _sp_auth: StartProcessAuth
  let _bp_auth: ApplyReleaseBackpressureAuth

  new create(env: Env,
    on_down: (String val | None),
    on_up: (String val | None),
    on_slow: (String val | None),
    on_flap: (String val | None))
  =>
    _env = env
    _on_down = _HookParser(on_down, "on_down")
    _on_up = _HookParser(on_up, "on_up")
    _on_slow = _HookParser(on_slow, "on_slow")
    _on_flap = _HookParser(on_flap, "on_flap")
    _sp_auth = StartProcessAuth(env.root)
    _bp_auth = ApplyReleaseBackpressureAuth(env.root)

  be event(e: StateEvent val) =>
    let config = match e.to_status
    | StatusDown => _on_down
    | StatusUp => _on_up
    | StatusSlow => _on_slow
    | StatusFlapping => _on_flap
    else None
    end
    match config
    | let cfg: HookConfig val =>
      _run(cfg, e)
    | None => None
    end

  fun _run(cfg: HookConfig val, e: StateEvent val) =>
    let path = FilePath(FileAuth(_env.root), "/bin/sh")
    let args: Array[String] val = ["/bin/sh"; "-c"; cfg.cmd]
    let event_val = StatusText(e.to_status)
    let target_s = e.target.string()
    let message = e.message
    let vars = recover trn Array[String] end
    vars.push("LANSENTINEL_EVENT=" + event_val)
    vars.push("LANSENTINEL_TARGET=" + target_s)
    vars.push("LANSENTINEL_MESSAGE=" + message)
    let notify: ProcessNotify iso = HookNotify(_env, cfg)
    ProcessMonitor(_sp_auth, _bp_auth, consume notify, path, args, consume vars)

class HookNotify is ProcessNotify
  let _env: Env
  let _config: HookConfig val

  new iso create(env: Env, config: HookConfig val) =>
    _env = env
    _config = config

  fun ref created(process: ProcessMonitor ref) =>
    process.done_writing()

  fun ref stdout(process: ProcessMonitor ref, data: Array[U8] iso) =>
    let text = String.from_array(consume data)
    if text.size() > 0 then
      _env.out.print("[hook:" + _config.event_for + "] " + text.trim())
    end

  fun ref stderr(process: ProcessMonitor ref, data: Array[U8] iso) =>
    let text = String.from_array(consume data)
    if text.size() > 0 then
      _env.err.print("[hook:" + _config.event_for + "] " + text.trim())
    end

  fun ref failed(process: ProcessMonitor ref, err: ProcessError) =>
    _env.err.print("[hook:" + _config.event_for + "] error: " + err.string())

  fun ref dispose(process: ProcessMonitor ref, child_exit_status: ProcessExitStatus) =>
    match child_exit_status
    | let exited: Exited =>
      if exited.exit_code() != 0 then
        _env.err.print("[hook:" + _config.event_for + "] exited with code " + exited.exit_code().string())
      end
    | let signaled: Signaled =>
      _env.err.print("[hook:" + _config.event_for + "] terminated by signal " + signaled.signal().string())
    end

primitive _HookParser
  fun apply(cmd: (String val | None), event_for: String val): (HookConfig val | None) =>
    match cmd
    | let c: String val =>
      if c.size() > 0 then
        HookConfig(c, event_for)
      else
        None
      end
    | None => None
    end
