use "collections"

actor Renderer
  let _env: Env
  let _json: Bool
  let _prometheus: Bool
  let _no_clear: Bool
  let _once: Bool
  let _summary: Bool
  let _max_events: USize
  let _interval_ms: U64
  let _slow_ms: U64
  let _results: Map[String val, RenderUpdate val] = Map[String val, RenderUpdate val]
  let _events: Array[StateEvent val] = Array[StateEvent val]

  new create(env: Env, config: AppConfig val) =>
    _env = env
    _json = config.json
    _prometheus = config.prometheus
    _no_clear = config.no_clear
    _once = config.once
    _summary = config.summary
    _max_events = config.events
    _interval_ms = config.interval_ms
    _slow_ms = config.slow_ms

  be check(u: RenderUpdate val) =>
    let r = u.result
    if _json then
      _env.out.print(Json.check(r))
    elseif _prometheus then
      _env.out.print(Prometheus.check(r))
    elseif _once then
      _env.out.print(_once_row(r))
    else
      _results(r.target.string()) = u
      _draw()
    end

  be event(e: StateEvent val) =>
    if _json then
      _env.out.print(Json.event(e))
    elseif _prometheus then
      None
    elseif _once then
      None
    else
      _events.push(e)
      while _events.size() > _max_events do
        try _events.shift()? end
      end
      _draw()
    end

  be stopped() =>
    if not _json then _env.out.print("LanSentinel stopped.") end

  be start_once() =>
    if (not _json) and (not _prometheus) then
      _env.out.print("LanSentinel Check\n")
    end

  be once_done(summary: RunSummary val) =>
    if (not _json) and (not _prometheus) then
      _env.out.print("\nResult:")
      _env.out.print("  " + summary.healthy.string() + " healthy")
      _env.out.print("  " + summary.unhealthy.string() + " unhealthy")
    end

  fun ref _draw() =>
    if not _no_clear then
      _env.out.write("\x1B[2J\x1B[H")
    end
    _env.out.print(Version() + "   watching " + _results.size().string() +
      " targets   interval " + (_interval_ms / 1000).string() + "s   slow >" + _slow_ms.string() + "ms\n")
    _env.out.print("Name        Target              Status   Latency   Avg     Up%     Checks   Last")
    for u in _results.values() do
      _env.out.print(_row(u))
    end
    _env.out.print("\nRecent Events:")
    for e in _events.values() do
      _env.out.print(e.timestamp + "  " + e.target.string() + " " + e.message)
    end
    if _no_clear then _env.out.print("") end

  fun _row(u: RenderUpdate val): String val =>
    let r = u.result
    let s = u.stats
    _pad(r.target.display_name(), 10) + "  " +
    _pad(r.target.string(), 18) + "  " +
    _pad(StatusText(r.status), 7) + "  " +
    _pad(_latency(r.latency_ms), 7) + "  " +
    _pad(_latency(s.average_latency_ms), 7) + " " +
    _pad(_percent(s.uptime_percent), 7) + " " +
    _pad(s.total_checks.string(), 7) + " " + r.timestamp

  fun _once_row(r: CheckResult val): String val =>
    _pad(StatusText(r.status), 7) + " " + _pad(r.target.display_name(), 14) + " " +
    _pad(r.target.string(), 18) + " " + _pad(_latency(r.latency_ms), 6) + " " + r.message

  fun _latency(v: (U64 | None)): String val =>
    match v
    | let ms: U64 => ms.string() + "ms"
    | None => "-"
    end

  fun _pad(s: String val, width: USize): String val =>
    let out = recover trn String end
    out.append(s)
    var i = s.size()
    while i < width do
      out.push(' ')
      i = i + 1
    end
    consume out

  fun _percent(v: F64): String val =>
    // Pony stdlib formatting is intentionally small; one decimal is enough for the terminal UI.
    let tenths = (v * 10).u64()
    (tenths / 10).string() + "." + (tenths % 10).string()
