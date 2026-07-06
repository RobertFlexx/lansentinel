primitive ScanModeAuto
primitive ScanModeArp
primitive ScanModeFull

type ScanMode is (ScanModeAuto | ScanModeArp | ScanModeFull)

primitive ScanModeText
  fun apply(mode: ScanMode): String val =>
    match mode
    | ScanModeAuto => "auto"
    | ScanModeArp => "arp"
    | ScanModeFull => "full"
    end

  fun title(mode: ScanMode): String val =>
    match mode
    | ScanModeArp => "ARP-seeded TCP probes"
    | ScanModeFull => "Full TCP sweep"
    | ScanModeAuto => "auto"
    end

primitive ScanModeParser
  fun parse(input: String val): (ScanMode | String val) =>
    match input
    | "auto" => ScanModeAuto
    | "arp" => ScanModeArp
    | "full" => ScanModeFull
    else
      "Invalid --scan-mode value: " + input + "\n\nUse one of:\n  auto\n  arp\n  full"
    end
