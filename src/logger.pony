use "files"

actor EventLogger
  let _env: Env
  var _file: (File | None) = None

  new create(env: Env, path: (String val | None)) =>
    _env = env
    match path
    | let p: String val =>
      let fp = FilePath(FileAuth(env.root), p)
      match CreateFile(fp)
      | let f: File =>
        f.seek_end(0)
        _file = f
      else
        env.err.print("Warning: could not open log file: " + p)
      end
    | None => None
    end

  be event(e: StateEvent val) =>
    match _file
    | let f: File =>
      f.write(e.timestamp + " " + e.target.string() + " " +
        StatusText(e.from_status) + " -> " + StatusText(e.to_status) +
        " " + e.message + "\n")
      f.flush()
    | None => None
    end

  be close() =>
    match _file
    | let f: File => f.flush()
    | None => None
    end
