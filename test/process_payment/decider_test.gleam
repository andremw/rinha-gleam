import gleeunit
import rinha_gleam/process_payment/decider.{
  PostponeDecision, ProcessPaymentNow, decide,
}
import rinha_gleam/shared/processor.{Default, Fallback}
import rinha_gleam/shared/processors_health.{Health, ProcessorsHealth}

pub fn main() {
  gleeunit.main()
}

pub fn decides_to_postpone_decision_when_both_processors_are_failing_test() {
  let health =
    ProcessorsHealth(
      default: Health(failing: True, min_response_time: 5000),
      fallback: Health(failing: True, min_response_time: 5000),
    )

  let decision = decide(health)

  assert decision == PostponeDecision
}

pub fn decides_to_make_request_to_default_when_both_processors_are_available_test() {
  let health =
    ProcessorsHealth(
      default: Health(failing: False, min_response_time: 0),
      fallback: Health(failing: False, min_response_time: 0),
    )

  let decision = decide(health)

  assert decision == ProcessPaymentNow(Default)
}

pub fn decides_to_make_request_to_fallback_when_default_processor_is_failing_test() {
  let health =
    ProcessorsHealth(
      default: Health(failing: True, min_response_time: 0),
      fallback: Health(failing: False, min_response_time: 0),
    )

  let decision = decide(health)

  assert decision == ProcessPaymentNow(Fallback)
}
