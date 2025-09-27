import birl
import birl/duration.{Duration}
import gleeunit
import rinha_gleam/process_payment/decider.{
  PostponeDecision, ProcessPaymentNow, decide,
}
import rinha_gleam/shared/payment
import rinha_gleam/shared/processor.{Default, Fallback}
import rinha_gleam/shared/processors_health.{Health, ProcessorsHealth}
import youid/uuid

pub fn main() {
  gleeunit.main()
}

pub fn decides_to_postpone_decision_when_both_processors_are_failing_test() {
  let health =
    ProcessorsHealth(
      default: Health(failing: True, min_response_time: 5000),
      fallback: Health(failing: True, min_response_time: 5000),
    )
  let uuid = uuid.v7()
  let requested_at = birl.now()
  let payment =
    payment.Payment(amount: 10.0, correlation_id: uuid, requested_at:)

  let decision = decide(health, payment)

  assert decision == PostponeDecision(decide_in: Duration(5000))
}

pub fn decides_to_make_request_to_default_when_both_processors_are_available_test() {
  let health =
    ProcessorsHealth(
      default: Health(failing: False, min_response_time: 0),
      fallback: Health(failing: False, min_response_time: 0),
    )
  let uuid = uuid.v7()
  let requested_at = birl.now()
  let payment =
    payment.Payment(amount: 10.0, correlation_id: uuid, requested_at:)

  let decision = decide(health, payment)

  assert decision == ProcessPaymentNow(Default, payment)
}

pub fn decides_to_make_request_to_fallback_when_default_processor_is_failing_test() {
  let health =
    ProcessorsHealth(
      default: Health(failing: True, min_response_time: 0),
      fallback: Health(failing: False, min_response_time: 0),
    )
  let uuid = uuid.v7()
  let requested_at = birl.now()
  let payment =
    payment.Payment(amount: 10.0, correlation_id: uuid, requested_at:)

  let decision = decide(health, payment)

  assert decision == ProcessPaymentNow(Fallback, payment)
}

pub fn decides_to_postpone_to_the_earliest_time_possible_depending_on_the_min_response_time_of_the_processors_test() {
  let health =
    ProcessorsHealth(
      default: Health(failing: True, min_response_time: 5000),
      fallback: Health(failing: True, min_response_time: 1000),
    )
  let uuid = uuid.v7()
  let requested_at = birl.now()
  let payment =
    payment.Payment(amount: 10.0, correlation_id: uuid, requested_at:)

  let decision = decide(health, payment)

  assert decision == PostponeDecision(decide_in: Duration(1000))
}
