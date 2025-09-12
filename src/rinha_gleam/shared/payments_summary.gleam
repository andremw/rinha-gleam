import birl
import booklet.{type Booklet}
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/json.{type Json}
import gleam/otp/actor
import glyn/registry
import rinha_gleam/process_payment/processor/types.{
  type PaymentProcessor, Default, Fallback,
}
import rinha_gleam/shared/payment.{type Payment}
import wisp
import youid/uuid

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

pub type PaymentDTO {
  PaymentDTO(amount: Float, correlation_id: String, requested_at: String)
}

/// we'll spawn a named actor and later send messages to it using the name rather than the pid or subject.
/// this guarantees that only one actor of this type will exist
const actor_name = "PaymentsSummary"

pub fn start() {
  let registry = registry.new("payments-summary", message_decoder(), Shutdown)

  let summary =
    booklet.new(PaymentsSummary(
      default: Totals(total_requests: 0, total_amount: 0.0),
      fallback: Totals(total_requests: 0, total_amount: 0.0),
    ))

  let _ =
    actor.new_with_initialiser(200, fn(subject) {
      case registry.register(registry, actor_name, Nil) {
        Error(_) -> {
          wisp.log_info("NOT REGISTERED!")
          actor.initialised(summary)
          |> actor.returning(subject)
          |> Ok
        }
        Ok(selector) -> {
          wisp.log_info("REGISTERED!")
          let selector =
            process.new_selector()
            |> process.select(subject)
            |> process.merge_selector(selector)

          actor.initialised(summary)
          |> actor.selecting(selector)
          |> actor.returning(subject)
          |> Ok
        }
      }
    })
    |> actor.on_message(handle_message)
    |> actor.start()

  registry
}

pub fn register_new_payment(
  subject,
  payment: Payment,
  processor processor: PaymentProcessor,
) {
  let dto =
    PaymentDTO(
      amount: payment.amount,
      correlation_id: payment.correlation_id |> uuid.to_string(),
      requested_at: payment.requested_at |> birl.to_iso8601(),
    )
  registry.call(subject, actor_name, 100, fn(subject) {
    NewPayment(subject, dto, processor)
  })
}

pub fn read(subject) {
  registry.call(subject, actor_name, 100, Get)
}

pub fn stop(subject) {
  registry.send(subject, actor_name, Shutdown)
}

/// actor (runs in a separate process)
pub type Message {
  Shutdown
  NewPayment(
    reply_to: Subject(Nil),
    payment: PaymentDTO,
    processor: PaymentProcessor,
  )
  Get(reply_to: Subject(PaymentsSummary))
}

fn message_decoder() -> decode.Decoder(Message) {
  decode.one_of(shutdown_decoder(), [
    new_payment_decoder(),
    get_decoder(),
  ])
}

fn shutdown_decoder() {
  decode.map(atom_decoder("shutdown"), fn(_) { Shutdown })
}

fn new_payment_decoder() {
  use _ <- decode.field(0, atom_decoder("new_payment"))
  use reply_to <- decode.field(1, decode.dynamic)

  use payment <- decode.field(2, payment_decoder())

  use processor <- decode.field(3, processor_decoder())

  decode.success(NewPayment(
    reply_to: unsafe_cast_subject(reply_to),
    payment:,
    processor:,
  ))
}

fn get_decoder() {
  use _ <- decode.field(0, atom_decoder("get"))
  use reply_to <- decode.field(1, decode.dynamic)

  decode.success(Get(reply_to: unsafe_cast_subject(reply_to)))
}

// Unsafe cast for Subject decoding - use with caution
@external(erlang, "gleam_stdlib", "identity")
fn unsafe_cast_subject(value: decode.Dynamic) -> Subject(a)

fn atom_decoder(expected) {
  use value <- decode.then(atom.decoder())
  // echo atom.to_string(value) as { "ATOM FOR EXPECTED " <> expected }
  case atom.to_string(value) == expected {
    True -> decode.success(value)
    False -> decode.failure(value, "Expected atom: " <> expected)
  }
}

fn processor_decoder() {
  decode.one_of(decode.map(atom_decoder("default"), fn(_) { Default }), [
    decode.map(atom_decoder("fallback"), fn(_) { Fallback }),
  ])
}

fn payment_decoder() {
  use _ <- decode.field(0, atom_decoder("payment_d_t_o"))
  use amount <- decode.field(1, decode.float)
  use correlation_id <- decode.field(2, decode.string)
  use requested_at <- decode.field(3, decode.string)

  decode.success(PaymentDTO(amount:, correlation_id:, requested_at:))
}

fn handle_message(
  summary_booklet: booklet.Booklet(PaymentsSummary),
  message: Message,
) {
  case message {
    Get(reply_to:) -> {
      // echo "GETTING SUMMARY"
      process.send(reply_to, booklet.get(summary_booklet))
      actor.continue(summary_booklet)
    }
    NewPayment(reply_to, payment, processor) -> {
      // echo "Registering new payment"
      booklet.update(summary_booklet, fn(summary) {
        case processor {
          Default ->
            PaymentsSummary(
              ..summary,
              default: update_totals(summary.default, payment.amount),
            )
          Fallback ->
            PaymentsSummary(
              ..summary,
              fallback: update_totals(summary.fallback, payment.amount),
            )
        }
      })
      process.send(reply_to, Nil)
      actor.continue(summary_booklet)
    }
    Shutdown -> {
      actor.stop()
    }
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
