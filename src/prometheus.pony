primitive Prometheus
  fun check(r: CheckResult val): String val =>
    let name = Json.esc(r.target.display_name())
    let target = Json.esc(r.target.string())
    let up = if r.status is StatusDown then "0" else "1" end
    let latency = match r.latency_ms
    | let ms: U64 => ms.string()
    | None => "0"
    end
    "# HELP lansentinel_target_up Whether the target is up.\n" +
    "# TYPE lansentinel_target_up gauge\n" +
    "lansentinel_target_up{name=\"" + name + "\",target=\"" + target + "\"} " + up + "\n\n" +
    "# HELP lansentinel_latency_ms Last observed latency in milliseconds.\n" +
    "# TYPE lansentinel_latency_ms gauge\n" +
    "lansentinel_latency_ms{name=\"" + name + "\",target=\"" + target + "\"} " + latency
