class val Ipv4Address
  let value: U32

  new val create(value': U32) =>
    value = value'

  fun string(): String val =>
    ((value >> 24) and 0xff).string() + "." +
    ((value >> 16) and 0xff).string() + "." +
    ((value >> 8) and 0xff).string() + "." +
    (value and 0xff).string()

primitive Ipv4Parser
  fun parse(input: String val): (Ipv4Address val | String val) =>
    try
      var rest: String val = input
      var value: U32 = 0
      var count: USize = 0
      while count < 4 do
        let part: String val = try
          let dot = rest.find(".")?
          let p_iso = rest.substring(0, dot.isize())
          let p: String val = consume p_iso
          let next_iso = rest.substring((dot + 1).isize())
          rest = consume next_iso
          p
        else
          let p = rest
          rest = ""
          p
        end
        if part.size() == 0 then error end
        let n = part.u64()?
        if n > 255 then error end
        value = (value << 8) or n.u32()
        count = count + 1
      end
      if rest.size() != 0 then error end
      Ipv4Address(value)
    else
      "Invalid IPv4 address: " + input
    end
