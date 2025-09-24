import rinha_gleam/shared/processors_health.{type ProcessorsHealth}

pub type Decision {
  PostponePayment
}

pub fn decide(health: ProcessorsHealth) {
  let default_failing = health.default.failing
  let fallback_failing = health.fallback.failing
  let both_failing = default_failing && fallback_failing

  case both_failing {
    False -> todo
    True -> PostponePayment
  }
}
