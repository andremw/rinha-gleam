import gleam/bool
import rinha_gleam/shared/processor.{type Processor, Default}
import rinha_gleam/shared/processors_health.{type ProcessorsHealth}

pub type Decision {
  PostponePayment
  ProcessPaymentNow(processor: Processor)
}

pub fn decide(health: ProcessorsHealth) {
  let default_failing = health.default.failing
  let fallback_failing = health.fallback.failing
  let both_failing = default_failing && fallback_failing

  use <- bool.guard(when: both_failing, return: PostponePayment)

  ProcessPaymentNow(Default)
}
