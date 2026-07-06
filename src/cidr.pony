class val CidrRange
  let base: Ipv4Address val
  let prefix: U8
  let network: U32
  let first: U32
  let last: U32
  let count: U64

  new val create(base': Ipv4Address val, prefix': U8) =>
    base = base'
    prefix = prefix'
    let host_bits = 32 - prefix.u32()
    let mask: U32 = if prefix == 0 then 0 else U32.max_value() << host_bits end
    network = base.value and mask
    let total: U64 = 1 << host_bits.u64()
    count = total
    let network_u64 = network.u64()
    first = if total <= 2 then network else (network_u64 + 1).u32() end
    last = if total <= 2 then ((network_u64 + total) - 1).u32() else ((network_u64 + total) - 2).u32() end

  fun string(): String val =>
    Ipv4Address(network).string() + "/" + prefix.string()

  fun host_count(): U64 =>
    if count <= 2 then count else count - 2 end

  fun hosts(): Array[String val] val =>
    let out = recover trn Array[String val] end
    var ip = first
    while ip <= last do
      out.push(Ipv4Address(ip).string())
      if ip == U32.max_value() then break end
      ip = ip + 1
    end
    consume out

  fun contains(ip: String val): Bool =>
    match Ipv4Parser.parse(ip)
    | let addr: Ipv4Address val => (addr.value >= first) and (addr.value <= last)
    | let err: String val => false
    end

primitive CidrParser
  fun parse(input: String val, allow_large: Bool = false): (CidrRange val | String val) =>
    try
      let slash = input.find("/")?
      let ip_iso = input.substring(0, slash.isize())
      let ip_s: String val = consume ip_iso
      let prefix_iso = input.substring((slash + 1).isize())
      let prefix_s: String val = consume prefix_iso
      let prefix_u64 = prefix_s.u64()?
      if prefix_u64 > 32 then error end
      match Ipv4Parser.parse(ip_s)
      | let ip: Ipv4Address val =>
        let range = CidrRange(ip, prefix_u64.u8())
        if (not allow_large) and (range.host_count() > 254) then
          "Refusing to scan " + input + " by default.\n\n" +
          "That range contains too many addresses for a normal LAN scan.\n\n" +
          "Use a smaller CIDR such as:\n  " + Ipv4Address(range.network).string() + "/24\n\n" +
          "Or override with:\n  --allow-large-scan"
        else
          range
        end
      | let err: String val => err
      end
    else
      "Invalid CIDR: " + input + "\n\nExpected examples:\n  192.168.1.0/24\n  10.0.0.0/24"
    end

  fun from_router(router: String val): (CidrRange val | String val) =>
    match Ipv4Parser.parse(router)
    | let ip: Ipv4Address val => CidrRange(ip, 24)
    | let err: String val => err
    end
