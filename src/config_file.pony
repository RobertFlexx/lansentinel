use "files"

class val ConfigFileData
  let interval_ms: (U64 | None)
  let timeout_ms: (U64 | None)
  let slow_ms: (U64 | None)
  let flap_window_ms: (U64 | None)
  let flap_threshold: (U64 | None)
  let events: (USize | None)
  let log_path: (String val | None)
  let targets: Array[Target val] val
  let on_down: (String val | None)
  let on_up: (String val | None)
  let on_slow: (String val | None)
  let on_flap: (String val | None)

  new val create(
    interval_ms': (U64 | None),
    timeout_ms': (U64 | None),
    slow_ms': (U64 | None),
    flap_window_ms': (U64 | None),
    flap_threshold': (U64 | None),
    events': (USize | None),
    log_path': (String val | None),
    targets': Array[Target val] val,
    on_down': (String val | None),
    on_up': (String val | None),
    on_slow': (String val | None),
    on_flap': (String val | None))
  =>
    interval_ms = interval_ms'
    timeout_ms = timeout_ms'
    slow_ms = slow_ms'
    flap_window_ms = flap_window_ms'
    flap_threshold = flap_threshold'
    events = events'
    log_path = log_path'
    targets = targets'
    on_down = on_down'
    on_up = on_up'
    on_slow = on_slow'
    on_flap = on_flap'

primitive ConfigFileParser
  fun parse(env: Env, path: String val): (ConfigFileData val | String val) =>
    var interval_ms: (U64 | None) = None
    var timeout_ms: (U64 | None) = None
    var slow_ms: (U64 | None) = None
    var flap_window_ms: (U64 | None) = None
    var flap_threshold: (U64 | None) = None
    var events: (USize | None) = None
    var log_path: (String val | None) = None
    var on_down: (String val | None) = None
    var on_up: (String val | None) = None
    var on_slow: (String val | None) = None
    var on_flap: (String val | None) = None
    let targets = recover trn Array[Target val] end

    let fp = FilePath(FileAuth(env.root), path)
    match OpenFile(fp)
    | let file: File =>
      var line_no: USize = 0
      for line_iso in FileLines(file) do
        line_no = line_no + 1
        let line: String val = consume line_iso
        let trimmed = _trim(line)
        if (trimmed.size() == 0) or _starts_with(trimmed, "#") then continue end
        match _parse_line(trimmed, line_no)
        | let t: Target val => targets.push(t)
        | (let key: String val, let value: String val) =>
          match key
          | "interval" => match DurationParser.parse(value) | let v: U64 => interval_ms = v | let e: String val => return e end
          | "timeout" => match DurationParser.parse(value) | let v: U64 => timeout_ms = v | let e: String val => return e end
          | "slow" => match DurationParser.parse(value) | let v: U64 => slow_ms = v | let e: String val => return e end
          | "flap_window" => match DurationParser.parse(value) | let v: U64 => flap_window_ms = v | let e: String val => return e end
          | "flap_threshold" => try flap_threshold = value.u64()? else return "Invalid flap_threshold in config line " + line_no.string() end
          | "events" => try events = value.usize()? else return "Invalid events in config line " + line_no.string() end
          | "log" => log_path = value
          | "on_down" => on_down = value
          | "on_up" => on_up = value
          | "on_slow" => on_slow = value
          | "on_flap" => on_flap = value
          else
            return "Invalid config line " + line_no.string() + ":\n  " + trimmed + "\n\nUnknown key: " + key
          end
        | let err: String val => return err
        end
      end
    else
      return "Could not open config file: " + path
    end

    ConfigFileData(interval_ms, timeout_ms, slow_ms, flap_window_ms,
      flap_threshold, events, log_path, consume targets, on_down, on_up,
      on_slow, on_flap)

  fun _parse_line(line: String val, line_no: USize): (Target val | (String val, String val) | String val) =>
    if _starts_with(line, "target ") then
      let rest = _trim(line.substring(7))
      try
        let sp = rest.find(" ")?
        let name_iso = rest.substring(0, sp.isize())
        let name: String val = consume name_iso
        let spec_iso = rest.substring((sp + 1).isize())
        let spec: String val = consume spec_iso
        if (name.size() == 0) or (spec.size() == 0) then error end
        TargetParser.parse_tcp(name, spec)
      else
        "Invalid config line " + line_no.string() + ":\n  " + line + "\n\nExpected:\n  target <name> <host:port>"
      end
    elseif _starts_with(line, "http ") then
      let rest = _trim(line.substring(5))
      try
        let sp = rest.find(" ")?
        let name_iso = rest.substring(0, sp.isize())
        let name: String val = consume name_iso
        let url_iso = rest.substring((sp + 1).isize())
        let url: String val = consume url_iso
        if (name.size() == 0) or (url.size() == 0) then error end
        TargetParser._parse_http_url(name, url)
      else
        "Invalid config line " + line_no.string() + ":\n  " + line + "\n\nExpected:\n  http <name> <http://host[:port]/path>"
      end
    else
      try
        let eq = line.find("=")?
        let key_iso = line.substring(0, eq.isize())
        let key = _trim(consume key_iso)
        let val_iso = line.substring((eq + 1).isize())
        let value = _trim(consume val_iso)
        if key.size() == 0 then error end
        (key, value)
      else
        "Invalid config line " + line_no.string() + ":\n  " + line + "\n\nExpected:\n  key = value\n  target <name> <host:port>\n  http <name> <http://host[:port]/path>"
      end
    end

  fun _starts_with(s: String val, prefix: String val): Bool =>
    (s.size() >= prefix.size()) and (s.substring(0, prefix.size().isize()) == prefix)

  fun _trim(s: String val): String val =>
    let out = recover trn String end
    var start: USize = 0
    var finish: USize = s.size()
    try
      while (start < finish) and ((s(start)? == ' ') or (s(start)? == '\t') or (s(start)? == '\n') or (s(start)? == '\r')) do
        start = start + 1
      end
      while (finish > start) and ((s(finish - 1)? == ' ') or (s(finish - 1)? == '\t') or (s(finish - 1)? == '\n') or (s(finish - 1)? == '\r')) do
        finish = finish - 1
      end
      var i = start
      while i < finish do
        out.push(s(i)?)
        i = i + 1
      end
    end
    consume out
