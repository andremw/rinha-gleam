import birl/duration.{type Duration, Duration}
import gleam/bool
import gleam/int
import rinha_gleam/shared/payment.{type Payment}
import rinha_gleam/shared/processor_types.{
  type PaymentProcessor, Default, Fallback,
}
import rinha_gleam/shared/processors_health.{type ProcessorsHealth}

pub type Decision {
  PostponeDecision(decide_in: Duration)
  ProcessPaymentNow(processor: PaymentProcessor, payment: Payment)
}

pub fn decide(health: ProcessorsHealth, payment) {
  let default_failing = health.default.failing
  let fallback_failing = health.fallback.failing
  let both_failing = default_failing && fallback_failing

  use <- bool.guard(
    when: both_failing,
    return: PostponeDecision(
      decide_in: Duration(int.min(
        health.default.min_response_time,
        health.fallback.min_response_time,
      )),
    ),
  )

  use <- bool.guard(
    when: default_failing,
    return: ProcessPaymentNow(Fallback, payment),
  )

  ProcessPaymentNow(Default, payment)
}
