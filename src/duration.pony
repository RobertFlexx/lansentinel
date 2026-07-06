primitive DurationParser
  fun parse(input: String val): (U64 | String val) =>
    try
      if input.size() < 2 then error end

      if input.size() >= 3 then
        let suffix_iso = input.substring((input.size() - 2).isize())
        let suffix: String val = consume suffix_iso
        if suffix == "ms" then
          let number_iso = input.substring(0, (input.size() - 2).isize())
          let number: String val = consume number_iso
          let n = number.u64()?
          if n == 0 then error end
          return n
        end
      end

      let unit_iso = input.substring((input.size() - 1).isize())
      let unit: String val = consume unit_iso
      let number_iso = input.substring(0, (input.size() - 1).isize())
      let number: String val = consume number_iso
      let n = number.u64()?
      if n == 0 then error end

      if unit == "s" then
        n * 1000
      elseif unit == "m" then
        n * 60 * 1000
      else
        error
      end
    else
      "Invalid duration: " + input + "\n\nUse values like:\n  500ms\n  5s\n  1m"
    end
