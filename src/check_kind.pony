primitive CheckTCP
primitive CheckHTTP

type CheckKind is (CheckTCP | CheckHTTP)

primitive CheckKindText
  fun apply(k: CheckKind): String val =>
    match k
    | CheckTCP => "tcp"
    | CheckHTTP => "http"
    end
