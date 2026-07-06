use "net"
use "time"
use "collections"

interface tag MdnsHandler
  be mdns_results(ips: Map[String val, String val] val, services: Map[String val, Array[String val] val] val)

actor MdnsProbe
  let _env: Env
  let _handler: MdnsHandler tag
  var _socket: (UDPSocket tag | None) = None
  let _timers: Timers = Timers
  let _hostnames: Map[String val, String val] = Map[String val, String val]
  let _svc_map: Map[String val, Array[String val] ref] = Map[String val, Array[String val] ref]
  var _started: Bool = false
  var _done: Bool = false

  new create(env: Env, handler: MdnsHandler tag) =>
    _env = env
    _handler = handler

  be start() =>
    if _started then return end
    _started = true
    let auth = UDPAuth(_env.root)
    let dns_auth = DNSAuth(_env.root)
    let addrs = DNS.ip4(dns_auth, "224.0.0.251", "5353")
    let query_addr = try addrs(0)? else
      _done = true; _report(); return
    end
    let notify: UDPNotify iso = MdnsNotify(this, query_addr)
    _socket = UDPSocket(auth, consume notify, "", "5353")
    let t = Timer(MdnsTimeout(this), 3_000_000_000)
    _timers(consume t)

  be receive(from_ip: String val, data: Array[U8] val) =>
    _parse_response(data)

  be timeout() =>
    if _done then return end
    _done = true
    match _socket | let s: UDPSocket tag => s.dispose() end
    _report()

  fun ref _report() =>
    let ip_map = recover trn Map[String val, String val] end
    for (ip, hn) in _hostnames.pairs() do
      ip_map(ip) = hn
    end
    let svc_map = recover trn Map[String val, Array[String val] val] end
    for (ip, svcs) in _svc_map.pairs() do
      let copied = recover trn Array[String val] end
      for s in svcs.values() do copied.push(s) end
      svc_map(ip) = consume copied
    end
    _handler.mdns_results(consume ip_map, consume svc_map)

  fun ref _parse_response(data: Array[U8] val) =>
    try
      if data.size() < 12 then return end
      let answers = ((data(6)?.u16() << 8) or data(7)?.u16()).usize()
      let auth_count = ((data(8)?.u16() << 8) or data(9)?.u16()).usize()
      let add_count = ((data(10)?.u16() << 8) or data(11)?.u16()).usize()
      var pos: USize = 12
      let qcount = ((data(4)?.u16() << 8) or data(5)?.u16()).usize()
      var i: USize = 0
      while i < qcount do
        pos = _skip_name(data, pos)?
        pos = pos + 4
        i = i + 1
      end
      pos = _parse_records(data, pos, answers)?
      pos = _parse_records(data, pos, auth_count)?
      pos = _parse_records(data, pos, add_count)?
    end

  fun ref _parse_records(data: Array[U8] val, offset: USize, count: USize): USize ? =>
    var pos = offset
    var i: USize = 0
    while i < count do
      let nlen = _name_len(data, pos)?
      pos = pos + nlen
      let atype = ((data(pos)?.u16() << 8) or data(pos + 1)?.u16())
      pos = pos + 4
      let rdlength = ((data(pos)?.u16() << 8) or data(pos + 1)?.u16()).usize()
      pos = pos + 2
      match atype
      | 1 => _parse_a(data, pos, rdlength)?
      | 33 => None
      end
      pos = pos + rdlength
      i = i + 1
    end
    pos

  fun _name_len(data: Array[U8] val, offset: USize): USize ? =>
    var pos = offset
    while pos < data.size() do
      let b = data(pos)?
      if (b and 0xC0) == 0xC0 then
        return (pos - offset) + 2
      elseif b == 0 then
        return (pos - offset) + 1
      else
        pos = pos + 1 + b.usize()
      end
    end
    error

  fun _skip_name(data: Array[U8] val, offset: USize): USize ? =>
    let len = _name_len(data, offset)?
    offset + len

  fun ref _parse_a(data: Array[U8] val, pos: USize, rdlength: USize) ? =>
    if rdlength == 4 then
      let ip: String val = recover val
        String.from_array([as U8: data(pos)?; 46; data(pos+1)?; 46; data(pos+2)?; 46; data(pos+3)?])
      end
      if not _hostnames.contains(ip) then
        _hostnames(ip) = ip
      end
    end

class iso MdnsNotify is UDPNotify
  let _probe: MdnsProbe tag
  let _query_addr: NetAddress val

  new iso create(probe: MdnsProbe tag, query_addr: NetAddress val) =>
    _probe = probe
    _query_addr = query_addr

  fun ref listening(sock: UDPSocket ref) =>
    sock.multicast_join("224.0.0.251")
    _send_query(sock, "_services._dns-sd._udp.local")
    _send_query(sock, "_http._tcp.local")
    _send_query(sock, "_ssh._tcp.local")
    _send_query(sock, "_airplay._tcp.local")
    _send_query(sock, "_ipp._tcp.local")
    _send_query(sock, "_smb._tcp.local")
    _send_query(sock, "_googlecast._tcp.local")
    _send_query(sock, "_companion-link._tcp.local")

  fun _send_query(sock: UDPSocket ref, service: String val) =>
    let packet = recover trn Array[U8] end
    packet.push(0); packet.push(0)
    packet.push(0); packet.push(0x01)
    packet.push(0); packet.push(0x01)
    packet.push(0); packet.push(0x00)
    packet.push(0); packet.push(0x00)
    packet.push(0); packet.push(0x00)
    for label in service.split(".").values() do
      packet.push(label.size().u8())
      for ch in label.values() do
        packet.push(ch)
      end
    end
    packet.push(0)
    packet.push(0x00); packet.push(0x0C)
    packet.push(0x00); packet.push(0x01)
    sock.write(consume packet, _query_addr)

  fun ref received(sock: UDPSocket ref, data: Array[U8] iso, from: NetAddress) =>
    try
      let from_ip = from.name()?._1
      _probe.receive(from_ip, consume data)
    end

  fun ref not_listening(sock: UDPSocket ref) =>
    None

class iso MdnsTimeout is TimerNotify
  let _probe: MdnsProbe tag

  new iso create(probe: MdnsProbe tag) =>
    _probe = probe

  fun ref apply(timer: Timer, count: U64): Bool =>
    _probe.timeout()
    false
