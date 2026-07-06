use "collections"

class val ServiceInfo
  let port: U16
  let protocol: String val
  let status: String val
  let latency_ms: (U64 | None)
  let banner: (String val | None)
  let http_status: (U64 | None)
  let http_title: (String val | None)
  let http_server: (String val | None)
  let os_hint: (String val | None)

  new val create(
    port': U16,
    protocol': String val,
    status': String val,
    latency_ms': (U64 | None),
    banner': (String val | None) = None,
    http_status': (U64 | None) = None,
    http_title': (String val | None) = None,
    http_server': (String val | None) = None,
    os_hint': (String val | None) = None)
  =>
    port = port'
    protocol = protocol'
    status = status'
    latency_ms = latency_ms'
    banner = banner'
    http_status = http_status'
    http_title = http_title'
    http_server = http_server'
    os_hint = os_hint'

class val DeviceInfo
  let ip: String val
  let mac: (String val | None)
  let vendor: (String val | None)
  let hostname: (String val | None)
  let alive: Bool
  let services: Array[ServiceInfo val] val
  let first_seen: String val
  let last_seen: String val
  let latency_ms: (U64 | None)
  let notes: (String val | None)
  let confidence: String val
  let discovery_tags: Array[String val] val

  new val create(
    ip': String val,
    services': Array[ServiceInfo val] val,
    mac': (String val | None) = None,
    vendor': (String val | None) = None,
    hostname': (String val | None) = None,
    alive': Bool = true,
    first_seen': String val = "-",
    last_seen': String val = "-",
    latency_ms': (U64 | None) = None,
    notes': (String val | None) = None,
    confidence': String val = "tcp-connect",
    discovery_tags': Array[String val] val = recover val Array[String val] end)
  =>
    ip = ip'
    services = services'
    mac = mac'
    vendor = vendor'
    hostname = hostname'
    alive = alive'
    first_seen = first_seen'
    last_seen = last_seen'
    latency_ms = latency_ms'
    notes = notes'
    confidence = confidence'
    discovery_tags = discovery_tags'

class val InventoryData
  let range: String val
  let devices: Array[DeviceInfo val] val
  let generated_at: String val
  let discovery_methods: Array[String val] val

  new val create(range': String val, devices': Array[DeviceInfo val] val, generated_at': String val,
    discovery_methods': Array[String val] val = recover val Array[String val] end) =>
    range = range'
    devices = devices'
    generated_at = generated_at'
    discovery_methods = discovery_methods'

class ref DeviceBuilder
  let ip: String val
  let services: Array[ServiceInfo val] = Array[ServiceInfo val]
  var first_seen: String val = "-"
  var last_seen: String val = "-"
  var best_latency: (U64 | None) = None
  var mac: (String val | None) = None
  var vendor: (String val | None) = None
  var hostname: (String val | None) = None
  let tags: Array[String val] = Array[String val]

  new create(ip': String val) => ip = ip'

  fun ref add_service(s: ServiceInfo val, ts: String val) =>
    if first_seen == "-" then first_seen = ts end
    last_seen = ts
    services.push(s)
    match s.latency_ms
    | let ms: U64 =>
      match best_latency
      | let best: U64 => if ms < best then best_latency = ms end
      | None => best_latency = ms
      end
    | None => None
    end

  fun ref add_tag(t: String val) =>
    for existing in tags.values() do
      if existing == t then return end
    end
    tags.push(t)

  fun snapshot(): DeviceInfo val =>
    let copied = recover trn Array[ServiceInfo val] end
    for s in services.values() do copied.push(s) end
    let tags_copied = recover trn Array[String val] end
    for t in tags.values() do tags_copied.push(t) end
    DeviceInfo(ip, consume copied, mac, vendor, hostname, true, first_seen, last_seen, best_latency, None, "tcp-connect", consume tags_copied)

primitive ServiceNames
  fun apply(port: U16): String val =>
    match port
    | 22 => "ssh"
    | 53 => "dns"
    | 80 => "http"
    | 139 => "netbios"
    | 443 => "https/tcp"
    | 445 => "smb"
    | 631 => "ipp"
    | 1883 => "mqtt"
    | 7070 => "http"
    | 8000 => "http"
    | 8080 => "http"
    | 8123 => "http"
    | 8443 => "https/tcp"
    | 25565 => "minecraft"
    else "tcp"
    end

  fun protocol(port: U16): String val =>
    match port
    | 80 => "http"
    | 7070 => "http"
    | 8000 => "http"
    | 8080 => "http"
    | 8123 => "http"
    else "tcp"
    end
