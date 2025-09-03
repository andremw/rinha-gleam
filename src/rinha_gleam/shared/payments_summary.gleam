import booklet.{type Booklet}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/json.{type Json}
import gleam/otp/actor
import rinha_gleam/process_payment/processor/types.{
  type Payment, type PaymentProcessor,
}

// client types (used by the processes that interact this actor)

pub type Totals {
  Totals(total_requests: Int, total_amount: Float)
}

pub type PaymentsSummary {
  PaymentsSummary(default: Totals, fallback: Totals)
}

fn encode_totals(totals: Totals) {
  json.object([
    #("totalRequests", json.int(totals.total_requests)),
    #("totalAmount", json.float(totals.total_amount)),
  ])
}

pub fn encode(summary: PaymentsSummary) -> Json {
  json.object([
    #("default", encode_totals(summary.default)),
    #("fallback", encode_totals(summary.fallback)),
  ])
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

pub fn register_new_payment(
  subject,
  payment,
  processor processor: PaymentProcessor,
) {
  process.call_forever(subject, NewPayment(_, payment, processor))
}

pub fn read(subject) {
  process.call_forever(subject, Get)
}

/// actor (runs in a separate process)
pub type Message {
  Shutdown
  NewPayment(
    reply_to: Subject(Nil),
    payment: Payment,
    processor: PaymentProcessor,
  )
  Get(reply_to: Subject(PaymentsSummary))
}

fn handle_message(summary_booklet: Booklet(PaymentsSummary), message: Message) {
  case message {
    Get(reply_to:) -> {
      process.send(reply_to, booklet.get(summary_booklet))
      actor.continue(summary_booklet)
    }
    NewPayment(reply_to:, payment:, processor:) -> {
      booklet.update(summary_booklet, fn(summary) {
        case processor {
          types.Default ->
            PaymentsSummary(
              ..summary,
              default: update_totals(summary.default, payment.amount),
            )
          types.Fallback ->
            PaymentsSummary(
              ..summary,
              fallback: update_totals(summary.fallback, payment.amount),
            )
        }
      })
      process.send(reply_to, Nil)
      actor.continue(summary_booklet)
    }
    Shutdown -> actor.stop()
  }
}

fn update_totals(totals: Totals, amount_to_add) {
  Totals(
    total_requests: totals.total_requests + 1,
    total_amount: p2(totals.total_amount +. amount_to_add),
  )
}

fn p2(n) {
  float.to_precision(n, 2)
}
