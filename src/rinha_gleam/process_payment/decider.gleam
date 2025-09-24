import gleam/bool
import rinha_gleam/shared/processor.{type Processor, Default, Fallback}
import rinha_gleam/shared/processors_health.{type ProcessorsHealth}

pub type Decision {
  PostponeDecision
  ProcessPaymentNow(processor: Processor)
}

pub fn decide(health: ProcessorsHealth) {
  let default_failing = health.default.failing
  let fallback_failing = health.fallback.failing
  let both_failing = default_failing && fallback_failing

  use <- bool.guard(when: both_failing, return: PostponeDecision)

  use <- bool.guard(when: default_failing, return: ProcessPaymentNow(Fallback))

  ProcessPaymentNow(Default)
}
