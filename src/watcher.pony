use "net"
use "time"

actor TargetWatcher
  let _supervisor: Supervisor
  let _target: Target val
  let _interval_ms: U64
  let _slow_ms: U64
  let _flap_window_ms: U64
  let _flap_threshold: U64
  var _last_status: Status = StatusUnknown
  let _changes: Array[U64] = Array[U64]
  var _flapping_until_ms: U64 = 0
  var _flap_reported: Bool = false
  var _started: Bool = false
  var _stopped: Bool = false
  var _timers: Timers = Timers

  new create(supervisor: Supervisor, target: Target val, interval_ms: U64, slow_ms: U64, flap_window_ms: U64, flap_threshold: U64) =>
    _supervisor = supervisor
    _target = target
    _interval_ms = interval_ms
    _slow_ms = slow_ms
    _flap_window_ms = flap_window_ms
    _flap_threshold = flap_threshold

  be start(auth: TCPConnectAuth, once: Bool) =>
    if not _started then
      _started = true
      check(auth)
      if not once then
        let timer = Timer(WatcherTimer(this, auth), _interval_ms * 1000000, _interval_ms * 1000000)
        _timers(consume timer)
      end
    end

  be stop() =>
    _stopped = true
    _timers.dispose()

  be check(auth: TCPConnectAuth) =>
    if _stopped then return end
    TCPConnection(auth, CheckNotify(this, _target, _slow_ms, Clock.epoch_ms()), _target.host, _target.port.string())

  be checked(r: CheckResult val) =>
    let actual_status = r.status
    if actual_status isnt _last_status then
      let now = Clock.epoch_ms()
      _changes.push(now)
      while (_changes.size() > 0) and ((now - try _changes(0)? else now end) > _flap_window_ms) do
        try _changes.shift()? end
      end
      let e = StateEvent(_target, _last_status, actual_status,
        EventMessage(_last_status, actual_status, r.message), r.timestamp)
      _supervisor.event(e)
      _last_status = actual_status
      if (_changes.size().u64() >= _flap_threshold) and not _flap_reported then
        _flap_reported = true
        _flapping_until_ms = now + _flap_window_ms
        _supervisor.event(StateEvent(_target, actual_status, StatusFlapping,
          "is FLAPPING, " + _changes.size().string() + " changes in " + (_flap_window_ms / 1000).string() + "s", r.timestamp))
      end
    end
    if Clock.epoch_ms() > _flapping_until_ms then _flap_reported = false end
    if _flap_reported then
      _supervisor.check(CheckResult(_target, StatusFlapping, r.latency_ms, r.message, r.timestamp))
    else
      _supervisor.check(r)
    end

class iso WatcherTimer is TimerNotify
  let _watcher: TargetWatcher
  let _auth: TCPConnectAuth

  new iso create(watcher: TargetWatcher, auth: TCPConnectAuth) =>
    _watcher = watcher
    _auth = auth

  fun ref apply(timer: Timer, count: U64): Bool =>
    _watcher.check(_auth)
    true

class iso CheckNotify is TCPConnectionNotify
  let _watcher: TargetWatcher
  let _target: Target val
  let _slow_ms: U64
  let _start_ms: U64
  var _reported: Bool = false

  new iso create(watcher: TargetWatcher, target: Target val, slow_ms: U64, start_ms: U64) =>
    _watcher = watcher
    _target = target
    _slow_ms = slow_ms
    _start_ms = start_ms

  fun ref connected(conn: TCPConnection ref) =>
    if _target.kind is CheckHTTP then
      conn.write("GET " + _target.path + " HTTP/1.1\r\nHost: " + _target.host + "\r\nConnection: close\r\nUser-Agent: LanSentinel/0.2.0\r\n\r\n")
    elseif not _reported then
      _reported = true
      let latency = Clock.epoch_ms() - _start_ms
      let status: Status = if latency > _slow_ms then StatusSlow else StatusUp end
      let message = if status is StatusSlow then "slow" else "ok" end
      _watcher.checked(CheckResult(_target, status, latency, message, Clock.time_of_day()))
      conn.close()
    end

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize): Bool =>
    if (not _reported) and (_target.kind is CheckHTTP) then
      _reported = true
      let latency = Clock.epoch_ms() - _start_ms
      let response = String.from_array(consume data)
      let code = _status_code(response)
      if (code >= 200) and (code < 400) then
        let status: Status = if latency > _slow_ms then StatusSlow else StatusUp end
        let message_iso = if status is StatusSlow then "slow: HTTP " + code.string() else "HTTP " + code.string() end
        let message: String val = consume message_iso
        _watcher.checked(CheckResult(_target, status, latency, message, Clock.time_of_day()))
      else
        let message_iso = "HTTP " + code.string()
        let message: String val = consume message_iso
        _watcher.checked(CheckResult(_target, StatusDown, latency, message, Clock.time_of_day()))
      end
      conn.close()
    end
    false

  fun ref connect_failed(conn: TCPConnection ref) =>
    if not _reported then
      _reported = true
      _watcher.checked(CheckResult(_target, StatusDown, None, "connection failed", Clock.time_of_day()))
    end

  fun ref closed(conn: TCPConnection ref) =>
    None

  fun _status_code(response: String val): U64 =>
    try
      let first_space = response.find(" ")?
      let rest_iso = response.substring((first_space + 1).isize())
      let rest: String val = consume rest_iso
      let second_space = rest.find(" ")?
      let code_iso = rest.substring(0, second_space.isize())
      let code: String val = consume code_iso
      code.u64()?
    else
      0
    end
