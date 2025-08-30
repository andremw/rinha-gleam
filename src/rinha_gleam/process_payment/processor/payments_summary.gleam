import booklet.{type Booklet}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/otp/actor
import rinha_gleam/process_payment/processor/types.{type Payment}

// client types (used by the processes that interact this actor)

pub type Totals {
  Totals(total_requests: Int, total_amount: Float)
}

pub type PaymentsSummary {
  PaymentsSummary(default: Totals, fallback: Totals)
}

/// we'll spawn a named actor and later send messages to it using the name rather than the pid or subject.
/// this guarantees that only one actor of this type will exist
const actor_name = "PaymentsSummary"

pub fn start() {
  let summary =
    booklet.new(PaymentsSummary(
      default: Totals(total_requests: 0, total_amount: 0.0),
      fallback: Totals(total_requests: 0, total_amount: 0.0),
    ))
  let name = process.new_name(actor_name)
  let _ =
    actor.new(summary)
    |> actor.on_message(handle_message)
    |> actor.named(name)
    |> actor.start()

  process.named_subject(name)
}

pub fn register_new_payment(subject, payment) {
  process.call_forever(subject, NewPayment(_, payment))
}

pub fn read(subject) {
  process.call_forever(subject, Get)
}

/// actor (runs in a separate process)
pub type Message {
  Shutdown
  NewPayment(reply_to: Subject(Nil), payment: Payment)
  Get(reply_to: Subject(PaymentsSummary))
}

fn handle_message(summary_booklet: Booklet(PaymentsSummary), message: Message) {
  case message {
    Get(reply_to:) -> {
      process.send(reply_to, booklet.get(summary_booklet))
      actor.continue(summary_booklet)
    }
    NewPayment(reply_to:, payment:) -> {
      booklet.update(summary_booklet, fn(summary) {
        PaymentsSummary(
          default: Totals(
            total_requests: summary.default.total_requests + 1,
            total_amount: p2(summary.default.total_amount +. payment.amount),
          ),
          fallback: Totals(total_requests: 0, total_amount: 0.0),
        )
      })
      process.send(reply_to, Nil)
      actor.continue(summary_booklet)
    }
    Shutdown -> actor.stop()
  }
}

fn p2(n) {
  float.to_precision(n, 2)
}
