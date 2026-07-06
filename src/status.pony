primitive StatusUnknown
primitive StatusUp
primitive StatusDown
primitive StatusSlow
primitive StatusFlapping

type Status is (StatusUnknown | StatusUp | StatusDown | StatusSlow | StatusFlapping)

primitive StatusText
  fun apply(s: Status): String val =>
    match s
    | StatusUnknown => "UNKNOWN"
    | StatusUp => "UP"
    | StatusDown => "DOWN"
    | StatusSlow => "SLOW"
    | StatusFlapping => "FLAP"
    end

  fun json(s: Status): String val =>
    match s
    | StatusUnknown => "unknown"
    | StatusUp => "up"
    | StatusDown => "down"
    | StatusSlow => "slow"
    | StatusFlapping => "flapping"
    end

  fun healthy(s: Status): Bool =>
    (s is StatusUp) or (s is StatusSlow) or (s is StatusFlapping)
