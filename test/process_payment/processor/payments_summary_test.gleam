import birl
import gleam/erlang/process
import gleam/float
import gleam/list
import gleeunit
import qcheck.{type Generator}
import rinha_gleam/process_payment/processor/payments_summary.{
  PaymentsSummary, Totals,
}
import rinha_gleam/process_payment/processor/types.{type Payment, Payment}
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn stores_concurrent_payment_information_test() {
  let requested_at = birl.now()
  let correlation_id = uuid.v7()

  use payments <- qcheck.given(payments(requested_at, correlation_id))
  let summary_subject = payments_summary.start()

  // define a message that can be sent to the parent process (this test case process)
  let completion_subject = process.new_subject()

  // spawn one process for each payment to simulate a random number of concurrent payments coming and updating
  // the payment summary with no race condition problems and good performance (otherwise the tests would be super slow)
  payments
  |> list.each(fn(payment) {
    use <- process.spawn

    let _ = payments_summary.register_new_payment(summary_subject, payment)

    // let the parent process know that this has been completed
    process.send(completion_subject, Nil)
  })

  // here we just force the test case process to wait for the completion message related to each payment. for example,
  // if the test generates 1000 payments, receive_forever will be called 1000 times, which means it'll only move to the
  // next line (after the list.each) after all processes have sent a message to that subject.
  payments
  |> list.each(fn(_) { process.receive_forever(completion_subject) })

  let payments_summary = payments_summary.read(summary_subject)

  let expected_count = list.length(payments)
  let expected_payment_total =
    payments
    |> list.map(fn(payment) { payment.amount })
    |> float.sum
    |> float.to_precision(2)

  assert payments_summary
    == PaymentsSummary(
      default: Totals(
        total_requests: expected_count,
        total_amount: expected_payment_total,
      ),
      fallback: Totals(total_requests: 0, total_amount: 0.0),
    )
}

// generators
fn payments(requested_at, correlation_id) -> Generator(List(Payment)) {
  use payment_count <- qcheck.bind(payment_count())

  qcheck.fixed_length_list_from(
    payment(requested_at, correlation_id),
    payment_count,
  )
}

fn payment(requested_at, correlation_id) -> Generator(Payment) {
  use amount <- qcheck.map(amount())
  let amount = float.to_precision(amount, 2)

  Payment(amount:, correlation_id:, requested_at:)
}

fn amount() -> Generator(Float) {
  qcheck.bounded_float(1.0, 100.0)
}

fn payment_count() -> Generator(Int) {
  qcheck.bounded_int(1, 30)
}
