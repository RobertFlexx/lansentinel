use "net"
use "time"
use "collections"

interface tag RevDnsHandler
  be revdns_results(names: Map[String val, String val] val)

actor RevDnsProbe
  let _env: Env
  let _handler: RevDnsHandler tag
  let _ips: Array[String val] val
  var _socket: (UDPSocket tag | None) = None
  let _timers: Timers = Timers
  let _names: Map[String val, String val] = Map[String val, String val]
  let _query_map: Map[U16, String val] = Map[U16, String val]
  var _started: Bool = false
  var _dns_server: (NetAddress val | None) = None
  var _dns_id: U16 = 1
  var _done: Bool = false

  new create(env: Env, handler: RevDnsHandler tag, ips: Array[String val] val) =>
    _env = env
    _handler = handler
    _ips = ips

  be start() =>
    if _started then return end
    _started = true
    if _ips.size() == 0 then
      _done = true
      _report()
      return
    end
    let auth = UDPAuth(_env.root)
    let dns_auth = DNSAuth(_env.root)
    let addrs = DNS.ip4(dns_auth, "8.8.8.8", "53")
    _dns_server = try addrs(0)? else
      _done = true; _report(); return
    end
    let notify: UDPNotify iso = RevDnsNotify(this)
    _socket = UDPSocket(auth, consume notify)
    let t = Timer(RevDnsTimeout(this), 2_000_000_000)
    _timers(consume t)

  be listening() =>
    for ip in _ips.values() do
      _send_ptr_query(ip)
    end

  be receive(data: Array[U8] val) =>
    _parse_ptr_response(data)

  be timeout() =>
    if _done then return end
    _done = true
    match _socket | let s: UDPSocket tag => s.dispose() end
    _report()

  fun ref _report() =>
    let result = recover trn Map[String val, String val] end
    for (ip, name) in _names.pairs() do
      result(ip) = name
    end
    _handler.revdns_results(consume result)

  be _send_ptr_query(ip: String val) =>
    try
      let addr = _dns_server as NetAddress val
      let parts = ip.split(".")
      if parts.size() != 4 then return end
      let id = _dns_id
      _query_map(id) = ip
      _dns_id = _dns_id + 1
      let ptr_name = parts(3)? + "." + parts(2)? + "." + parts(1)? + "." + parts(0)? + ".in-addr.arpa"
      let packet = recover trn Array[U8] end
      packet.push((id >> 8).u8()); packet.push((id and 0xFF).u8())
      packet.push(0x01); packet.push(0x00)
      packet.push(0); packet.push(0x01)
      packet.push(0); packet.push(0x00)
      packet.push(0); packet.push(0x00)
      packet.push(0); packet.push(0x00)
      for label in ptr_name.split(".").values() do
        packet.push(label.size().u8())
        for ch in label.values() do
          packet.push(ch)
        end
      end
      packet.push(0)
      packet.push(0x00); packet.push(0x0C)
      packet.push(0x00); packet.push(0x01)
      match _socket
      | let s: UDPSocket tag =>
        s.write(consume packet, addr)
      end
    end

  fun ref _parse_ptr_response(data: Array[U8] val) =>
    try
      if data.size() < 12 then return end
      let id = ((data(0)?.u16() << 8) or data(1)?.u16())
      let qr = data(2)? and 0x80
      if qr == 0 then return end
      let ancount = ((data(6)?.u16() << 8) or data(7)?.u16()).usize()
      if ancount == 0 then return end
      let ip = try _query_map(id)? else return end
      if _names.contains(ip) then return end
      var pos: USize = 12
      let qdcount = ((data(4)?.u16() << 8) or data(5)?.u16()).usize()
      var i: USize = 0
      while i < qdcount do
        pos = _skip_name(data, pos)?
        pos = pos + 4
        i = i + 1
      end
      pos = _skip_name(data, pos)?
      let atype = ((data(pos)?.u16() << 8) or data(pos + 1)?.u16())
      if atype != 12 then return end
      pos = pos + 8
      let rdlength = ((data(pos)?.u16() << 8) or data(pos + 1)?.u16()).usize()
      pos = pos + 2
      let name = _read_name(data, pos)?
      _names(ip) = name
    end

  fun ref _read_name(data: Array[U8] val, pos: USize): String val ? =>
    let out = recover iso Array[U8] end
    var p = pos
    var first = true
    var max_depth: USize = 10
    while (p < data.size()) and (max_depth > 0) do
      max_depth = max_depth - 1
      let b = data(p)?
      if (b and 0xC0) == 0xC0 then
        if not first then out.push(46) end
        first = false
        let off = (((b and 0x3F).usize() << 8) or data(p + 1)?.usize())
        p = off
        continue
      elseif b == 0 then
        break
      else
        if not first then out.push(46) end
        first = false
        p = p + 1
        var j: USize = 0
        while j < b.usize() do
          out.push(data(p + j)?)
          j = j + 1
        end
        p = p + b.usize()
      end
    end
    recover val String.from_array(consume out) end

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

class iso RevDnsNotify is UDPNotify
  let _probe: RevDnsProbe tag

  new iso create(probe: RevDnsProbe tag) =>
    _probe = probe

  fun ref received(sock: UDPSocket ref, data: Array[U8] iso, from: NetAddress) =>
    _probe.receive(consume data)

  fun ref listening(sock: UDPSocket ref) =>
    _probe.listening()

  fun ref not_listening(sock: UDPSocket ref) =>
    None

class iso RevDnsTimeout is TimerNotify
  let _probe: RevDnsProbe tag

  new iso create(probe: RevDnsProbe tag) =>
    _probe = probe

  fun ref apply(timer: Timer, count: U64): Bool =>
    _probe.timeout()
    false
