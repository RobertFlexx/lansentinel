use "files"

primitive LocalNetwork
  fun detect(env: Env): (CidrRange val | String val) =>
    let fp = FilePath(FileAuth(env.root), "/proc/net/route")
    match OpenFile(fp)
    | let file: File =>
      var line_no: USize = 0
      var default_iface: (String val | None) = None
      let routes = recover trn Array[(String val, U32, U32)] end

      for line_iso in FileLines(file) do
        line_no = line_no + 1
        if line_no == 1 then continue end
        let line: String val = consume line_iso
        try
          let iface = _field(line, 0)?
          let dest = _hex_le(_field(line, 1)?)?
          let mask = _hex_le(_field(line, 7)?)?
          if (dest == 0) and (mask == 0) then
            default_iface = iface
          else
            routes.push((iface, dest, mask))
          end
        end
      end

      match default_iface
      | let iface: String val =>
        for r in routes.values() do
          if (r._1 == iface) and (r._3 != 0) then
            let prefix = _prefix_len(r._3)
            if prefix > 0 then return CidrRange(Ipv4Address(r._2), prefix) end
          end
        end
        "Could not infer local LAN range from /proc/net/route for interface " + iface + ".\n\nPass --scan CIDR instead."
      | None =>
        "Could not find a default route in /proc/net/route.\n\nPass --scan CIDR instead."
      end
    else
      "Could not read /proc/net/route.\n\nPass --scan CIDR instead."
    end

  fun _field(line: String val, wanted: USize): String val ? =>
    let out = recover trn String end
    var field: USize = 0
    var in_field = false
    for c in line.values() do
      if (c == ' ') or (c == '\t') then
        if in_field then
          if field == wanted then return consume out end
          field = field + 1
          in_field = false
          out.clear()
        end
      else
        in_field = true
        if field == wanted then out.push(c) end
      end
    end
    if in_field and (field == wanted) then consume out else error end

  fun _hex_le(s: String val): U32 ? =>
    var raw: U32 = 0
    for c in s.values() do
      raw = (raw << 4) or _hex_digit(c)?
    end
    ((raw and 0x000000ff) << 24) or
      ((raw and 0x0000ff00) << 8) or
      ((raw and 0x00ff0000) >> 8) or
      ((raw and 0xff000000) >> 24)

  fun _hex_digit(c: U8): U32 ? =>
    if (c >= '0') and (c <= '9') then
      (c - '0').u32()
    elseif (c >= 'a') and (c <= 'f') then
      ((c - 'a') + 10).u32()
    elseif (c >= 'A') and (c <= 'F') then
      ((c - 'A') + 10).u32()
    else
      error
    end

  fun _prefix_len(mask: U32): U8 =>
    var count: U8 = 0
    var bit: U32 = 0x80000000
    while bit != 0 do
      if (mask and bit) != 0 then
        count = count + 1
        bit = bit >> 1
      else
        break
      end
    end
    count
