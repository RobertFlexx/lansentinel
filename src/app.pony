class val CheckResult
  let target: Target val
  let status: Status
  let latency_ms: (U64 | None)
  let message: String val
  let timestamp: String val

  new val create(
    target': Target val,
    status': Status,
    latency_ms': (U64 | None),
    message': String val,
    timestamp': String val)
  =>
    target = target'
    status = status'
    latency_ms = latency_ms'
    message = message'
    timestamp = timestamp'

class val StateEvent
  let target: Target val
  let from_status: Status
  let to_status: Status
  let message: String val
  let timestamp: String val

  new val create(
    target': Target val,
    from_status': Status,
    to_status': Status,
    message': String val,
    timestamp': String val)
  =>
    target = target'
    from_status = from_status'
    to_status = to_status'
    message = message'
    timestamp = timestamp'

primitive EventMessage
  fun apply(from_status: Status, to_status: Status, message: String val): String val =>
    match to_status
    | StatusUp =>
      match from_status
      | StatusDown => "recovered"
      | StatusSlow => "is healthy again"
      else "is UP"
      end
    | StatusDown => "went DOWN: " + message
    | StatusSlow => "became SLOW: " + message
    | StatusFlapping => "is FLAPPING: " + message
    | StatusUnknown => "is UNKNOWN"
    end

class val RenderUpdate
  let result: CheckResult val
  let stats: StatsSnapshot val

  new val create(result': CheckResult val, stats': StatsSnapshot val) =>
    result = result'
    stats = stats'

class val RunSummary
  let checks: U64
  let healthy: U64
  let unhealthy: U64

  new val create(checks': U64, healthy': U64, unhealthy': U64) =>
    checks = checks'
    healthy = healthy'
    unhealthy = unhealthy'
