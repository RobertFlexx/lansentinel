use "collections"
use "files"

primitive ArpCache
  fun read(env: Env): Map[String val, String val] ref =>
    let result = Map[String val, String val]
    let fp = FilePath(FileAuth(env.root), "/proc/net/arp")
    match OpenFile(fp)
    | let file: File =>
      var line_no: USize = 0
      for line_iso in FileLines(file) do
        line_no = line_no + 1
        if line_no == 1 then continue end
        let line: String val = consume line_iso
        try
          let ip = _field(line, 0)?
          let mac = _field(line, 3)?
          if (ip.size() > 0) and (mac.size() >= 17) then result(ip) = mac end
        end
      end
    else
      None
    end
    result

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
