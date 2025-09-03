import birl
import gleam/erlang/process
import gleam/float
import gleam/list
import gleam/pair
import gleeunit
import qcheck.{type Generator}
import rinha_gleam/process_payment/processor/types.{
  type Payment, type PaymentProcessor, Default, Fallback, Payment,
}
import rinha_gleam/shared/payments_summary.{PaymentsSummary, Totals}
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn stores_concurrent_payment_information_test() {
  let requested_at = birl.now()
  let correlation_id = uuid.v7()

  use payments_tuples <- qcheck.given(payments(requested_at, correlation_id))
  let summary_subject = payments_summary.start()

  // define a message that can be sent to the parent process (this test case process)
  let completion_subject = process.new_subject()

  // spawn one process for each payment to simulate a random number of concurrent payments coming and updating
  // the payment summary with no race condition problems and good performance (otherwise the tests would be super slow)
  payments_tuples
  |> list.each(fn(payment_tuple) {
    let #(payment, processor) = payment_tuple

    use <- process.spawn

    let _ =
      payments_summary.register_new_payment(summary_subject, payment, processor)

    // let the parent process know that this has been completed
    process.send(completion_subject, Nil)
  })

  // here we just force the test case process to wait for the completion message related to each payment. for example,
  // if the test generates 1000 payments, receive_forever will be called 1000 times, which means it'll only move to the
  // next line (after the list.each) after all processes have sent a message to that subject.
  payments_tuples
  |> list.each(fn(_) { process.receive_forever(completion_subject) })

  let payments_summary = payments_summary.read(summary_subject)

  let #(payments_using_default, payments_using_fallback) =
    payments_tuples
    |> list.partition(fn(tuple) {
      let #(_, processor) = tuple
      case processor {
        Default -> True
        Fallback -> False
      }
    })
    |> pair.map_first(list.map(_, pair.first))
    |> pair.map_second(list.map(_, pair.first))

  let requests_default = list.length(payments_using_default)
  let requests_fallback = list.length(payments_using_fallback)
  let total_default = sum_payments(payments_using_default)
  let total_fallback = sum_payments(payments_using_fallback)

  assert payments_summary
    == PaymentsSummary(
      default: Totals(
        total_requests: requests_default,
        total_amount: total_default,
      ),
      fallback: Totals(
        total_requests: requests_fallback,
        total_amount: total_fallback,
      ),
    )
}

fn sum_payments(payments: List(Payment)) {
  payments
  |> list.map(fn(payment) { payment.amount })
  |> float.sum
  |> float.to_precision(2)
}

// generators
fn payments(
  requested_at,
  correlation_id,
) -> Generator(List(#(Payment, PaymentProcessor))) {
  use payment_count <- qcheck.bind(payment_count())

  qcheck.fixed_length_list_from(
    payment(requested_at, correlation_id),
    payment_count,
  )
}

fn payment(
  requested_at,
  correlation_id,
) -> Generator(#(Payment, PaymentProcessor)) {
  use amount, processor <- qcheck.map2(amount(), processor())
  let amount = float.to_precision(amount, 2)

  #(Payment(amount:, correlation_id:, requested_at:), processor)
}

fn amount() -> Generator(Float) {
  qcheck.bounded_float(1.0, 100.0)
}

fn payment_count() -> Generator(Int) {
  qcheck.bounded_int(1, 30)
}

fn processor() -> Generator(PaymentProcessor) {
  qcheck.from_generators(qcheck.constant(Default), [qcheck.constant(Fallback)])
}
