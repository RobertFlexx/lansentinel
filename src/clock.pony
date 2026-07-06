use "time"

primitive Clock
  fun epoch_ms(): U64 =>
    let now = Time.now()
    ((now._1.u64() * 1000) + (now._2.u64() / 1000000))

  fun timestamp(): String val =>
    let now = Time.now()
    now._1.string() + "Z"

  fun time_of_day(): String val =>
    let secs = Time.now()._1.u64()
    let day = secs % 86400
    let h = day / 3600
    let m = (day % 3600) / 60
    let s = day % 60
    _pad2(h) + ":" + _pad2(m) + ":" + _pad2(s)

  fun _pad2(n: U64): String val =>
    if n < 10 then "0" + n.string() else n.string() end
