import gleam/http/response
import gleam/json
import gleam/uri
import gleeunit
import glenvy/dotenv
import glenvy/env
import rinha_gleam/process_payment
import rinha_gleam/process_payment/context.{Context, HttpClient}
import rinha_gleam/shared/payments_summary.{PaymentsSummary, Totals}
import rinha_gleam/shared/processors_health.{Health, ProcessorsHealth}
import wisp/testing
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

fn setup() {
  let _ = dotenv.load()

  let assert Ok(default_url) = env.string("PROCESSOR_DEFAULT_URL")
  let assert Ok(fallback_url) = env.string("PROCESSOR_FALLBACK_URL")
  let assert Ok(default_uri) = uri.parse(default_url)
  let assert Ok(fallback_uri) = uri.parse(fallback_url)
  let summary_subject = payments_summary.start()

  let status = Health(failing: False, min_response_time: 5)
  Context(
    http_client: HttpClient(send: fn(_req) { Ok(response.new(200)) }),
    processor_default_uri: default_uri,
    processor_fallback_uri: fallback_uri,
    processors_health: ProcessorsHealth(default: status, fallback: status),
    summary_subject:,
  )
}

pub fn handler_returns_a_simple_response_test() {
  let uuid = uuid.v4() |> uuid.to_string
  let body =
    json.object([
      #("amount", json.float(19.9)),
      #("correlationId", json.string(uuid)),
    ])

  let request = testing.post_json("http://localhost:9999/payments", [], body)
  let ctx = setup()
  let response = process_payment.handle_request(request, ctx)

  assert response.status == 200
}

pub fn handler_requires_amount_test() {
  let body = json.object([#("correlationId", json.string(""))])

  let request = testing.post_json("http://localhost:9999/payments", [], body)
  let ctx = setup()
  let response = process_payment.handle_request(request, ctx)

  assert response.status == 400
}

pub fn handler_requires_correlation_id_uuid_test() {
  let body =
    json.object([
      #("amount", json.float(19.9)),
      #("correlationId", json.string("")),
    ])
  let request = testing.post_json("http://localhost:9999/payments", [], body)
  let ctx = setup()
  let response = process_payment.handle_request(request, ctx)

  assert response.status == 400
}

pub fn stores_payment_summary_when_successful_test() {
  let ctx = setup()

  assert payments_summary.read(ctx.summary_subject)
    == PaymentsSummary(
      default: Totals(total_requests: 0, total_amount: 0.0),
      fallback: Totals(total_requests: 0, total_amount: 0.0),
    )

  let uuid = uuid.v4() |> uuid.to_string
  let body =
    json.object([
      #("amount", json.float(19.9)),
      #("correlationId", json.string(uuid)),
    ])
  let request = testing.post_json("http://localhost:9999/payments", [], body)

  // we don't care about the response here
  let _ = process_payment.handle_request(request, ctx)

  assert payments_summary.read(ctx.summary_subject)
    == PaymentsSummary(
      default: Totals(total_requests: 1, total_amount: 19.9),
      fallback: Totals(total_requests: 0, total_amount: 0.0),
    )
}
