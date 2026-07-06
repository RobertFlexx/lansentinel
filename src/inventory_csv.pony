use "files"

primitive InventoryCsv
  fun save(env: Env, path: String val, inv: InventoryData val): Bool =>
    let fp = FilePath(FileAuth(env.root), path)
    match CreateFile(fp)
    | let f: File =>
      f.set_length(0)
      f.write("ip,hostname,mac,vendor,ports,services,last_seen\n")
      for d in inv.devices.values() do
        f.write(_row(d) + "\n")
      end
      f.flush()
      true
    else
      env.err.print("Warning: could not save inventory: " + path)
      false
    end

  fun _row(d: DeviceInfo val): String val =>
    _csv(d.ip) + "," + _csv(_opt(d.hostname)) + "," + _csv(_opt(d.mac)) + "," +
    _csv(_opt(d.vendor)) + "," + _csv(_ports(d)) + "," + _csv(_services(d)) + "," + _csv(d.last_seen)

  fun _opt(v: (String val | None)): String val => match v | let s: String val => s | None => "" end

  fun _ports(d: DeviceInfo val): String val =>
    let out = recover trn String end
    var first = true
    for s in d.services.values() do
      if not first then out.append(";") end
      first = false
      out.append(s.port.string())
    end
    consume out

  fun _services(d: DeviceInfo val): String val =>
    let out = recover trn String end
    var first = true
    for s in d.services.values() do
      if not first then out.append(";") end
      first = false
      out.append(s.port.string() + "/" + s.protocol)
    end
    consume out

  fun _csv(s: String val): String val =>
    "\"" + Json.esc(s) + "\""
