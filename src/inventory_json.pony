use "files"

primitive InventoryJson
  fun render(inv: InventoryData val): String val =>
    let out = recover trn String end
    out.append("{\"type\":\"inventory\",\"range\":\"")
    out.append(Json.esc(inv.range))
    out.append("\",\"generated_at\":\"")
    out.append(Json.esc(inv.generated_at))
    out.append("\",\"devices\":[")
    var first_device = true
    for d in inv.devices.values() do
      if not first_device then out.append(",") end
      first_device = false
      out.append(_device(d))
    end
    out.append("],\"discovery_methods\":[")
    first_device = true
    for m in inv.discovery_methods.values() do
      if not first_device then out.append(",") end
      first_device = false
      out.append("\"" + Json.esc(m) + "\"")
    end
    out.append("]}")
    consume out

  fun _device(d: DeviceInfo val): String val =>
    let out = recover trn String end
    out.append("{\"ip\":\"")
    out.append(Json.esc(d.ip))
    out.append("\",\"mac\":")
    out.append(_opt_str(d.mac))
    out.append(",\"vendor\":")
    out.append(_opt_str(d.vendor))
    out.append(",\"hostname\":")
    out.append(_opt_str(d.hostname))
    out.append(",\"alive\":")
    out.append(if d.alive then "true" else "false" end)
    out.append(",\"first_seen\":\"")
    out.append(Json.esc(d.first_seen))
    out.append("\",\"last_seen\":\"")
    out.append(Json.esc(d.last_seen))
    out.append("\",\"confidence\":\"")
    out.append(Json.esc(d.confidence))
    out.append("\",\"latency_ms\":")
    out.append(_opt_u64(d.latency_ms))
    out.append(",\"notes\":")
    out.append(_opt_str(d.notes))
    out.append(",\"services\":[")
    var first = true
    for s in d.services.values() do
      if not first then out.append(",") end
      first = false
      out.append(_service(s))
    end
    out.append("],\"discovery_tags\":[")
    first = true
    for t in d.discovery_tags.values() do
      if not first then out.append(",") end
      first = false
      out.append("\"" + Json.esc(t) + "\"")
    end
    out.append("]}")
    consume out

  fun _service(s: ServiceInfo val): String val =>
    let out = recover trn String end
    out.append("{\"port\":")
    out.append(s.port.string())
    out.append(",\"protocol\":\"")
    out.append(Json.esc(s.protocol))
    out.append("\",\"status\":\"")
    out.append(Json.esc(s.status))
    out.append("\",\"latency_ms\":")
    out.append(_opt_u64(s.latency_ms))
    out.append(",\"banner\":")
    out.append(_opt_str(s.banner))
    out.append(",\"http_status\":")
    out.append(_opt_u64(s.http_status))
    out.append(",\"http_title\":")
    out.append(_opt_str(s.http_title))
    out.append(",\"http_server\":")
    out.append(_opt_str(s.http_server))
    out.append(",\"os_hint\":")
    out.append(_opt_str(s.os_hint))
    out.append("}")
    consume out

  fun _opt_str(v: (String val | None)): String val =>
    match v | let s: String val => "\"" + Json.esc(s) + "\"" | None => "null" end

  fun _opt_u64(v: (U64 | None)): String val =>
    match v | let n: U64 => n.string() | None => "null" end

  fun save(env: Env, path: String val, inv: InventoryData val): Bool =>
    let fp = FilePath(FileAuth(env.root), path)
    match CreateFile(fp)
    | let f: File =>
      f.set_length(0)
      f.write(render(inv) + "\n")
      f.flush()
      true
    else
      env.err.print("Error: could not save inventory: " + path)
      false
    end

  fun load(env: Env, path: String val): (InventoryData val | String val) =>
    let fp = FilePath(FileAuth(env.root), path)
    match OpenFile(fp)
    | let file: File =>
      var content = recover trn String end
      for line_iso in FileLines(file) do
        let line: String val = consume line_iso
        content.append(line)
      end
      _parse(consume content, path)
    else
      "Could not open inventory: " + path
    end

  fun _parse(content: String val, src_path: String val): InventoryData val =>
    let range = _extract_string(content, "\"range\":\"", "\"")
    let generated_at = _extract_string(content, "\"generated_at\":\"", "\"")
    let devices = recover trn Array[DeviceInfo val] end
    try
      var rest: String val = content
      while true do
        let device_start = rest.find("\"ip\":\"")?
        let after_start_iso = rest.substring(device_start.isize())
        let after_start: String val = consume after_start_iso
        (let device_rest: String val, let device_out: DeviceInfo val) = _parse_device(after_start)
        rest = device_rest
        devices.push(device_out)
      end
    end
    InventoryData(
      if range.size() > 0 then range else src_path end,
      consume devices,
      if generated_at.size() > 0 then generated_at else Clock.time_of_day() end)

  fun _parse_device(input: String val): (String val, DeviceInfo val) =>
    let ip = _extract_string(input, "\"ip\":\"", "\"")
    var rest: String val = input
    let mac = _extract_string(rest, "\"mac\":", "\"")
    let vendor = _extract_string(rest, "\"vendor\":", "\"")
    let hostname = _extract_string(rest, "\"hostname\":", "\"")
    let alive = _extract_alive(rest)
    let first_seen = _extract_string(rest, "\"first_seen\":\"", "\"")
    let last_seen = _extract_string(rest, "\"last_seen\":\"", "\"")
    let confidence = _extract_string(rest, "\"confidence\":\"", "\"")
    let latency = _extract_u64(rest, "\"latency_ms\":")
    let notes = _extract_string(rest, "\"notes\":", "\"")
    let services = _parse_services(rest)
    let d = DeviceInfo(ip, services,
      if mac.size() > 0 then mac else None end,
      if vendor.size() > 0 then vendor else None end,
      if hostname.size() > 0 then hostname else None end,
      alive,
      if first_seen.size() > 0 then first_seen else "-" end,
      if last_seen.size() > 0 then last_seen else "-" end,
      latency,
      if notes.size() > 0 then notes else None end,
      if confidence.size() > 0 then confidence else "tcp-connect" end)
    (rest, d)

  fun _parse_services(input: String val): Array[ServiceInfo val] val =>
    let services = recover trn Array[ServiceInfo val] end
    try
      let svc_start = input.find("\"services\":[")?
      var rest: String val = recover val input.substring((svc_start + 11).isize()) end
      while true do
        let port_key = rest.find("\"port\":")?
        let after_port_iso = rest.substring((port_key + 7).isize())
        let after_port: String val = consume after_port_iso
        let comma = after_port.find(",")?
        let port_iso = after_port.substring(0, comma.isize())
        let port_s: String val = consume port_iso
        let port = port_s.u64()?.u16()
        let protocol = _extract_string(after_port, "\"protocol\":\"", "\"")
        let status = _extract_string(after_port, "\"status\":\"", "\"")
        let latency = _extract_u64(after_port, "\"latency_ms\":")
        let banner = _extract_string(after_port, "\"banner\":", "\"")
        let http_status = _extract_u64(after_port, "\"http_status\":")
        let http_title = _extract_string(after_port, "\"http_title\":", "\"")
        let http_server = _extract_string(after_port, "\"http_server\":", "\"")
        let svc = ServiceInfo(port,
          if protocol.size() > 0 then protocol else ServiceNames.protocol(port) end,
          if status.size() > 0 then status else "open" end,
          latency,
          if banner.size() > 0 then banner else None end,
          http_status,
          if http_title.size() > 0 then http_title else None end,
          if http_server.size() > 0 then http_server else None end)
        services.push(svc)
        if after_port.find("\"port\":", 0)? < 0 then error end
        rest = after_port
      end
    end
    consume services

  fun _extract_string(content: String val, key: String val, delimiter: String val): String val =>
    try
      let start = content.find(key)?
      let after_key: ISize = start.isize() + key.size().isize()
      let after_iso = content.substring(after_key)
      let after: String val = consume after_iso
      if after.size() == 0 then return "" end
      if after(0)? == 'n' then return "" end
      if after(0)? == '"' then
        let after_quote_iso = after.substring(1)
        let after_quote: String val = consume after_quote_iso
        let end_delim = after_quote.find(delimiter)?
        let val_iso = after_quote.substring(0, end_delim.isize())
        consume val_iso
      else
        ""
      end
    else
      ""
    end

  fun _extract_u64(content: String val, key: String val): (U64 | None) =>
    try
      let start = content.find(key)?
      let after_key: ISize = start.isize() + key.size().isize()
      let after_iso = content.substring(after_key)
      let after: String val = consume after_iso
      if after.size() == 0 then return None end
      if after(0)? == 'n' then return None end
      var num: String val = ""
      try
        let comma = after.find(",")?
        let num_iso = after.substring(0, comma.isize())
        num = consume num_iso
      else
        let bracket = after.find("}")?
        let num_iso = after.substring(0, bracket.isize())
        num = consume num_iso
      end
      num.u64()?
    else
      None
    end

  fun _extract_alive(content: String val): Bool =>
    try
      let start = content.find("\"alive\":")?
      let after_iso = content.substring((start + 8).isize())
      let after: String val = consume after_iso
      after.substring(0, ISize(4)) == "true"
    else
      true
    end
