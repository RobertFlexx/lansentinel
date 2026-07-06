primitive Json
  fun esc(s: String val): String val =>
    let out = recover trn String end
    for c in s.values() do
      match c
      | '"' => out.append("\\\"")
      | '\\' => out.append("\\\\")
      | '\n' => out.append("\\n")
      | '\r' => out.append("\\r")
      | '\t' => out.append("\\t")
      else
        out.push(c)
      end
    end
    consume out

  fun check(r: CheckResult val): String val =>
    let latency = match r.latency_ms
    | let ms: U64 => ms.string()
    | None => "null"
    end
    "{\"type\":\"check\",\"name\":\"" + esc(r.target.display_name()) +
    "\",\"target\":\"" + esc(r.target.string()) +
    "\",\"check_kind\":\"" + CheckKindText(r.target.kind) +
    "\",\"status\":\"" + StatusText.json(r.status) +
    "\",\"latency_ms\":" + latency +
    ",\"message\":\"" + esc(r.message) +
    "\",\"timestamp\":\"" + esc(r.timestamp) + "\"}"

  fun event(e: StateEvent val): String val =>
    "{\"type\":\"event\",\"name\":\"" + esc(e.target.display_name()) +
    "\",\"target\":\"" + esc(e.target.string()) +
    "\",\"from\":\"" + StatusText.json(e.from_status) +
    "\",\"to\":\"" + StatusText.json(e.to_status) +
    "\",\"message\":\"" + esc(e.message) +
    "\",\"timestamp\":\"" + esc(e.timestamp) + "\"}"
