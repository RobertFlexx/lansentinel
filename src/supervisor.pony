use "net"
use "collections"

actor Supervisor
  let _env: Env
  let _config: AppConfig val
  let _renderer: Renderer
  let _logger: EventLogger
  let _hooks: HookRunner
  let _stats: Map[String val, TargetStats] = Map[String val, TargetStats]
  let _watchers: Array[TargetWatcher tag] = Array[TargetWatcher tag]
  var _stopped: Bool = false
  var _checks_seen: USize = 0
  var _unhealthy_seen: USize = 0

  new create(env: Env, config: AppConfig val) =>
    _env = env
    _config = config
    _renderer = Renderer(env, config)
    _logger = EventLogger(env, config.log_path)
    _hooks = HookRunner(env, config.on_down, config.on_up, config.on_slow, config.on_flap)

  be start() =>
    if _config.once then _renderer.start_once() end
    let auth = TCPConnectAuth(_env.root)
    for t in _config.targets.values() do
      let w = TargetWatcher(this, t, _config.interval_ms, _config.slow_ms,
        _config.flap_window_ms, _config.flap_threshold)
      _watchers.push(w)
      w.start(auth, _config.once)
    end

  be stop() =>
    if not _stopped then
      _stopped = true
      for w in _watchers.values() do
        w.stop()
      end
      _env.out.print("LanSentinel stopped.")
      _env.exitcode(0)
    end

  be check(r: CheckResult val) =>
    if _stopped then return end
    _checks_seen = _checks_seen + 1
    if r.status is StatusDown then _unhealthy_seen = _unhealthy_seen + 1 end
    let key = r.target.string()
    let stats = try _stats(key)? else
      let s = TargetStats
      _stats(key) = s
      s
    end
    stats.observe(r)
    _renderer.check(RenderUpdate(r, stats.snapshot()))
    if _config.once and (_checks_seen >= _config.targets.size()) then
      _logger.close()
      _renderer.once_done(RunSummary(_checks_seen.u64(),
        (_checks_seen - _unhealthy_seen).u64(), _unhealthy_seen.u64()))
      if _config.fail_fast and (_unhealthy_seen > 0) then
        _env.exitcode(1)
      else
        _env.exitcode(0)
      end
    end

  be event(e: StateEvent val) =>
    if _stopped then return end
    try _stats(e.target.string())?.changed() end
    _renderer.event(e)
    _logger.event(e)
    _hooks.event(e)
