use "net"
use "time"
use "collections"

interface tag SsdpHandler
  be ssdp_results(devices: Map[String val, SsdpDevice val] val)

class val SsdpDevice
  let ip: String val
  let server: (String val | None)
  let usn: (String val | None)
  let location: (String val | None)
  let st: (String val | None)

  new val create(ip': String val, server': (String val | None) = None,
    usn': (String val | None) = None, location': (String val | None) = None,
    st': (String val | None) = None) =>
    ip = ip'
    server = server'
    usn = usn'
    location = location'
    st = st'

  fun with_server(s: String val): SsdpDevice val =>
    SsdpDevice(ip, s, usn, location, st)

  fun with_usn(u: String val): SsdpDevice val =>
    SsdpDevice(ip, server, u, location, st)

  fun with_location(l: String val): SsdpDevice val =>
    SsdpDevice(ip, server, usn, l, st)

  fun with_st(s: String val): SsdpDevice val =>
    SsdpDevice(ip, server, usn, location, s)

actor SsdpProbe
  let _env: Env
  let _handler: SsdpHandler tag
  var _socket: (UDPSocket tag | None) = None
  let _timers: Timers = Timers
  let _devices: Map[String val, SsdpDevice val] = Map[String val, SsdpDevice val]
  var _started: Bool = false
  var _done: Bool = false

  new create(env: Env, handler: SsdpHandler tag) =>
    _env = env
    _handler = handler

  be start() =>
    if _started then return end
    _started = true
    let auth = UDPAuth(_env.root)
    let dns_auth = DNSAuth(_env.root)
    let addrs = DNS.ip4(dns_auth, "239.255.255.250", "1900")
    let query_addr = try addrs(0)? else
      _done = true; _report(); return
    end
    let notify: UDPNotify iso = SsdpNotify(this, query_addr)
    _socket = UDPSocket(auth, consume notify, "", "1900")
    let t = Timer(SsdpTimeout(this), 3_000_000_000)
    _timers(consume t)

  be receive(from_ip: String val, data: Array[U8] val) =>
    _parse_response(data)

  be timeout() =>
    if _done then return end
    _done = true
    match _socket | let s: UDPSocket tag => s.dispose() end
    _report()

  fun ref _report() =>
    let result = recover trn Map[String val, SsdpDevice val] end
    for (ip, d) in _devices.pairs() do
      result(ip) = d
    end
    _handler.ssdp_results(consume result)

  fun ref _parse_response(data: Array[U8] val) =>
    let text = String.from_array(data)
    var found = false
    try found = text.find("200 OK", 0)? >= 0 end
    if not found then
      try found = text.find("NOTIFY", 0)? >= 0 end
    end
    if not found then return end
    let ip = _extract_addr(text)
    if ip.size() == 0 then return end
    let existing = _devices.get_or_else(ip, SsdpDevice(ip))
    let server = _extract_field(text, "SERVER: ")
    let usn = _extract_field(text, "USN: ")
    let loc = _extract_field(text, "LOCATION: ")
    let st = _extract_field(text, "ST: ")
    var updated = existing
    if server.size() > 0 then updated = updated.with_server(server) end
    if usn.size() > 0 then updated = updated.with_usn(usn) end
    if loc.size() > 0 then updated = updated.with_location(loc) end
    if st.size() > 0 then updated = updated.with_st(st) end
    _devices(ip) = updated

  fun _extract_addr(text: String val): String val =>
    try
      let loc = _extract_field(text, "LOCATION: ")
      if loc.size() > 0 then
        let parts = loc.split("/")
        if parts.size() >= 3 then
          let host_part = parts(2)?
          let colon = host_part.find(":")?
          if colon > 0 then
            host_part.substring(0, colon.isize())
          else
            host_part
          end
        else
          ""
        end
      else
        ""
      end
    else
      ""
    end

  fun _extract_field(text: String val, key: String val): String val =>
    try
      let key_start = text.find(key)?
      if key_start < 0 then return "" end
      let after = (key_start + key.size().isize())
      let rest = text.substring(after)
      let end_pos = rest.find("\r")?
      if end_pos > 0 then
        rest.substring(0, end_pos.isize())
      else
        rest
      end
    else
      ""
    end

class iso SsdpNotify is UDPNotify
  let _probe: SsdpProbe tag
  let _query_addr: NetAddress val

  new iso create(probe: SsdpProbe tag, query_addr: NetAddress val) =>
    _probe = probe
    _query_addr = query_addr

  fun ref received(sock: UDPSocket ref, data: Array[U8] iso, from: NetAddress) =>
    try
      let from_ip = from.name()?._1
      _probe.receive(from_ip, consume data)
    end

  fun ref listening(sock: UDPSocket ref) =>
    sock.multicast_join("239.255.255.250")
    let msg = "M-SEARCH * HTTP/1.1\r\n" +
      "HOST: 239.255.255.250:1900\r\n" +
      "MAN: \"ssdp:discover\"\r\n" +
      "MX: 3\r\n" +
      "ST: ssdp:all\r\n" +
      "USER-AGENT: LanSentinel/0.2.0\r\n" +
      "\r\n"
    sock.write(msg.array(), _query_addr)

  fun ref not_listening(sock: UDPSocket ref) =>
    None

class iso SsdpTimeout is TimerNotify
  let _probe: SsdpProbe tag

  new iso create(probe: SsdpProbe tag) =>
    _probe = probe

  fun ref apply(timer: Timer, count: U64): Bool =>
    _probe.timeout()
    false
