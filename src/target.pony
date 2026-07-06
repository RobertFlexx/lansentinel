class val Target
  let name: (String val | None)
  let host: String val
  let port: U16
  let kind: CheckKind
  let path: String val

  new val create(
    name': (String val | None),
    host': String val,
    port': U16,
    kind': CheckKind = CheckTCP,
    path': String val = "/")
  =>
    name = name'
    host = host'
    port = port'
    kind = kind'
    path = path'

  fun string(): String val =>
    match kind
    | CheckHTTP => "http://" + host + if port == 80 then path else ":" + port.string() + path end
    | CheckTCP => host + ":" + port.string()
    end

  fun display_name(): String val =>
    match name
    | let n: String val => n
    | None => string()
    end

primitive TargetParser
  fun parse(input: String val): (Target val | String val) =>
    parse_tcp(None, input)

  fun parse_named(input: String val): (Target val | String val) =>
    try
      let eq = input.find("=")?
      let name_iso = input.substring(0, eq.isize())
      let name: String val = consume name_iso
      let spec_iso = input.substring((eq + 1).isize())
      let spec: String val = consume spec_iso
      if name.size() == 0 then error end
      match parse_tcp(name, spec)
      | let t: Target val => t
      | let err: String val => err
      end
    else
      "Invalid named target: " + input + "\n\nExpected:\n  --name Name=host:port\n\nExample:\n  --name WebApp=localhost:7070"
    end

  fun parse_http(input: String val, named: Bool = false): (Target val | String val) =>
    if named then
      try
        let eq = input.find("=")?
        let name_iso = input.substring(0, eq.isize())
        let name: String val = consume name_iso
        let url_iso = input.substring((eq + 1).isize())
        let url: String val = consume url_iso
        if name.size() == 0 then error end
        _parse_http_url(name, url)
      else
        "Invalid named HTTP target: " + input + "\n\nExpected:\n  --http-name Name=http://host[:port]/path"
      end
    else
      _parse_http_url(None, input)
    end

  fun parse_tcp(name: (String val | None), input: String val): (Target val | String val) =>
    try
      let colon = input.rfind(":")?
      let host_iso = input.substring(0, colon.isize())
      let host: String val = consume host_iso
      let port_iso = input.substring((colon + 1).isize())
      let port_s: String val = consume port_iso
      if host.size() == 0 then error end
      if port_s.size() == 0 then error end
      let port_u64 = port_s.u64()?
      if (port_u64 < 1) or (port_u64 > 65535) then error end
      Target(name, host, port_u64.u16())
    else
      "Invalid target: " + input + "\n\nExpected:\n  host:port\n\nExample:\n  localhost:7070"
    end

  fun _parse_http_url(name: (String val | None), url: String val): (Target val | String val) =>
    try
      if url.size() >= 8 then
        if url.substring(0, 8) == "https://" then
          return "HTTPS checks are not supported yet in pure Pony mode.\nUse TCP check example.com:443 for now."
        end
      end
      if (url.size() < 8) or (url.substring(0, 7) != "http://") then error end
      let rest_iso = url.substring(7)
      let rest: String val = consume rest_iso
      var host_port: String val = rest
      var path: String val = "/"
      try
        let slash = rest.find("/")?
        let hp_iso = rest.substring(0, slash.isize())
        host_port = consume hp_iso
        let path_iso = rest.substring(slash.isize())
        path = consume path_iso
      end
      if host_port.size() == 0 then error end
      var host: String val = host_port
      var port: U16 = 80
      try
        let colon = host_port.rfind(":")?
        let h_iso = host_port.substring(0, colon.isize())
        host = consume h_iso
        let p_iso = host_port.substring((colon + 1).isize())
        let p: String val = consume p_iso
        let port_u64 = p.u64()?
        if (port_u64 < 1) or (port_u64 > 65535) then error end
        port = port_u64.u16()
      end
      if host.size() == 0 then error end
      Target(name, host, port, CheckHTTP, path)
    else
      "Invalid HTTP target: " + url + "\n\nExpected:\n  http://host[:port]/path"
    end
