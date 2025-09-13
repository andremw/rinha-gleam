import birl
import birl/duration
import birl/interval
import booklet.{type Booklet}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/result
import rinha_gleam/process_payment/processor/types.{type PaymentProcessor}
import rinha_gleam/shared/payment.{type Payment}

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
  let summary = booklet.new([])
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

pub fn read(subject, from from, to to) {
  process.call_forever(subject, Get(_, from:, to:))
}

/// actor (runs in a separate process)
pub type Message {
  Shutdown
  NewPayment(
    reply_to: Subject(Nil),
    payment: Payment,
    processor: PaymentProcessor,
  )
  Get(
    reply_to: Subject(PaymentsSummary),
    from: Option(birl.Time),
    to: Option(birl.Time),
  )
}

fn handle_message(
  summary_booklet: Booklet(List(#(Payment, PaymentProcessor))),
  message: Message,
) {
  case message {
    Get(reply_to:, from:, to:) -> {
      let is_within_range = is_within_range(_, from:, to:)
      let payments = booklet.get(summary_booklet)
      let summary =
        payments
        |> list.fold(
          PaymentsSummary(
            default: Totals(total_requests: 0, total_amount: 0.0),
            fallback: Totals(total_requests: 0, total_amount: 0.0),
          ),
          with: fn(summary, payment_tuple) {
            let #(payment, processor) = payment_tuple

            case is_within_range(payment) {
              True ->
                case processor {
                  types.Default ->
                    PaymentsSummary(
                      default: update_totals(summary.default, payment.amount),
                      fallback: summary.fallback,
                    )
                  types.Fallback ->
                    PaymentsSummary(
                      default: summary.default,
                      fallback: update_totals(summary.fallback, payment.amount),
                    )
                }
              False -> summary
            }
          },
        )

      // wisp.log_info(
      //   "Sending back summary!\n"
      //   <> "?from="
      //   <> from |> option.map(birl.to_iso8601) |> string.inspect
      //   <> "&to="
      //   <> to |> option.map(birl.to_iso8601) |> string.inspect
      //   <> "\n"
      //   <> string.inspect(summary)
      //   <> "\n"
      //   <> "All payments count: "
      //   <> payments |> list.length |> int.to_string,
      // )

      process.send(reply_to, summary)
      actor.continue(summary_booklet)
    }
    NewPayment(reply_to:, payment:, processor:) -> {
      booklet.update(summary_booklet, fn(payments) {
        list.append(payments, [#(payment, processor)])
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

fn is_within_range(payment: Payment, from from, to to) {
  // if none, set to 1970
  let from = option.unwrap(from, birl.unix_epoch)
  // if some, set to 5 minutes into the future
  let to = option.unwrap(to, birl.add(birl.now(), duration.minutes(5)))

  interval.from_start_and_end(from, to)
  |> result.map(interval.includes(_, payment.requested_at))
  |> result.unwrap(False)
}
