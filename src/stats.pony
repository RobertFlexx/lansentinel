class ref TargetStats
  var total_checks: U64 = 0
  var up_checks: U64 = 0
  var slow_checks: U64 = 0
  var down_checks: U64 = 0
  var last_latency_ms: (U64 | None) = None
  var best_latency_ms: (U64 | None) = None
  var worst_latency_ms: (U64 | None) = None
  var latency_total_ms: U64 = 0
  var latency_count: U64 = 0
  var state_changes: U64 = 0
  var first_seen: String val = "-"
  var last_seen: String val = "-"
  var current_status: Status = StatusUnknown

  new create() => None

  fun ref observe(r: CheckResult val) =>
    if total_checks == 0 then first_seen = r.timestamp end
    total_checks = total_checks + 1
    last_seen = r.timestamp
    current_status = r.status
    match r.status
    | StatusUp => up_checks = up_checks + 1
    | StatusSlow => slow_checks = slow_checks + 1
    | StatusDown => down_checks = down_checks + 1
    | StatusFlapping => up_checks = up_checks + 1
    | StatusUnknown => None
    end
    last_latency_ms = r.latency_ms
    match r.latency_ms
    | let ms: U64 =>
      latency_total_ms = latency_total_ms + ms
      latency_count = latency_count + 1
      match best_latency_ms
      | let best: U64 => if ms < best then best_latency_ms = ms end
      | None => best_latency_ms = ms
      end
      match worst_latency_ms
      | let worst: U64 => if ms > worst then worst_latency_ms = ms end
      | None => worst_latency_ms = ms
      end
    | None => None
    end

  fun ref changed() =>
    state_changes = state_changes + 1

  fun avg_latency_ms(): (U64 | None) =>
    if latency_count == 0 then None else latency_total_ms / latency_count end

  fun uptime_percent(): F64 =>
    if total_checks == 0 then
      0
    else
      ((up_checks + slow_checks).f64() * 100) / total_checks.f64()
    end

  fun snapshot(): StatsSnapshot val =>
    StatsSnapshot(total_checks, up_checks, slow_checks, down_checks,
      last_latency_ms, best_latency_ms, worst_latency_ms, avg_latency_ms(),
      state_changes, first_seen, last_seen, current_status, uptime_percent())

class val StatsSnapshot
  let total_checks: U64
  let up_checks: U64
  let slow_checks: U64
  let down_checks: U64
  let last_latency_ms: (U64 | None)
  let best_latency_ms: (U64 | None)
  let worst_latency_ms: (U64 | None)
  let average_latency_ms: (U64 | None)
  let state_changes: U64
  let first_seen: String val
  let last_seen: String val
  let current_status: Status
  let uptime_percent: F64

  new val create(
    total_checks': U64,
    up_checks': U64,
    slow_checks': U64,
    down_checks': U64,
    last_latency_ms': (U64 | None),
    best_latency_ms': (U64 | None),
    worst_latency_ms': (U64 | None),
    average_latency_ms': (U64 | None),
    state_changes': U64,
    first_seen': String val,
    last_seen': String val,
    current_status': Status,
    uptime_percent': F64)
  =>
    total_checks = total_checks'
    up_checks = up_checks'
    slow_checks = slow_checks'
    down_checks = down_checks'
    last_latency_ms = last_latency_ms'
    best_latency_ms = best_latency_ms'
    worst_latency_ms = worst_latency_ms'
    average_latency_ms = average_latency_ms'
    state_changes = state_changes'
    first_seen = first_seen'
    last_seen = last_seen'
    current_status = current_status'
    uptime_percent = uptime_percent'
