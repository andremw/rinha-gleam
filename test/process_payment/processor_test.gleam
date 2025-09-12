import birl
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/string
import gleam/uri
import gleeunit
import glenvy/dotenv
import glenvy/env
import rinha_gleam/process_payment/context.{Context, HttpClient}
import rinha_gleam/process_payment/processor
import rinha_gleam/process_payment/processor/types.{Default, Fallback}
import rinha_gleam/shared/payment.{Payment}
import rinha_gleam/shared/payments_summary
import rinha_gleam/shared/processors_health.{Health, ProcessorsHealth}
import youid/uuid

pub fn main() {
  gleeunit.main()
}

fn setup() {
  let _ = dotenv.load()

  let assert Ok(default_url) = env.string("PROCESSOR_DEFAULT_URL")
  let assert Ok(fallback_url) = env.string("PROCESSOR_FALLBACK_URL")
  let assert Ok(default_uri) = uri.parse(default_url)
  let assert Ok(fallback_uri) = uri.parse(fallback_url)

  let amount = 10.5
  let correlation_id = uuid.v7()
  let requested_at = birl.now()
  let payment = Payment(amount:, correlation_id:, requested_at:)

  #(payment, default_uri, fallback_uri)
}

pub fn sends_a_request_to_default_payment_processor_test() {
  let #(payment, processor_default_uri, processor_fallback_uri) = setup()

  let body =
    json.object([
      #("amount", json.float(payment.amount)),
      #("correlation_id", json.string(uuid.to_string(payment.correlation_id))),
      #("requested_at", json.string(birl.to_iso8601(payment.requested_at))),
    ])
    |> json.to_string

  let assert Ok(expected_request) = request.from_uri(processor_default_uri)
  let expected_request = expected_request |> request.set_path("/payments")

  let expected_request =
    expected_request
    |> request.set_method(http.Post)
    |> request.set_body(body)

  let http_client =
    context.HttpClient(send: fn(req) {
      assert req == expected_request
      response.new(200) |> Ok
    })

  let summary_subject = payments_summary.start()

  let ctx =
    Context(
      http_client:,
      processor_default_uri:,
      processor_fallback_uri:,
      processors_health: ProcessorsHealth(
        default: Health(failing: False, min_response_time: 5),
        fallback: Health(failing: False, min_response_time: 5),
      ),
      summary_subject:,
    )

  let response = processor.process(payment, ctx)

  assert response == Ok(response.new(200) |> response.set_body(Default))
}

pub fn sends_a_request_to_fallback_payment_processor_if_request_to_default_processor_fails_test() {
  let #(payment, processor_default_uri, processor_fallback_uri) = setup()

  let http_client =
    HttpClient(send: fn(req) {
      // here we intentionally fail the request to the default processor
      case req.host |> string.contains("default") {
        True -> Error(Nil)
        False -> Ok(response.new(200))
      }
    })

  let summary_subject = payments_summary.start()

  let ctx =
    Context(
      http_client:,
      processor_default_uri:,
      processor_fallback_uri:,
      processors_health: ProcessorsHealth(
        default: Health(failing: False, min_response_time: 5),
        fallback: Health(failing: False, min_response_time: 5),
      ),
      summary_subject:,
    )

  let response = processor.process(payment, ctx)

  assert response == Ok(response.new(200) |> response.set_body(Fallback))
}

pub fn sends_a_direct_request_to_fallback_payment_processor_if_default_is_failing_test() {
  let #(payment, processor_default_uri, processor_fallback_uri) = setup()

  let http_client = HttpClient(send: fn(_req) { Ok(response.new(200)) })

  let summary_subject = payments_summary.start()

  let ctx =
    Context(
      http_client:,
      processor_default_uri:,
      processor_fallback_uri:,
      processors_health: ProcessorsHealth(
        default: Health(failing: True, min_response_time: 5),
        fallback: Health(failing: False, min_response_time: 5),
      ),
      summary_subject:,
    )

  let response = processor.process(payment, ctx)

  assert response == Ok(response.new(200) |> response.set_body(Fallback))
}

pub fn sends_a_direct_request_to_fallback_payment_processor_if_default_is_slower_test() {
  let #(payment, processor_default_uri, processor_fallback_uri) = setup()

  let http_client = HttpClient(send: fn(_req) { Ok(response.new(200)) })

  let summary_subject = payments_summary.start()

  let ctx =
    Context(
      http_client:,
      processor_default_uri:,
      processor_fallback_uri:,
      processors_health: ProcessorsHealth(
        default: Health(failing: False, min_response_time: 500),
        fallback: Health(failing: False, min_response_time: 5),
      ),
      summary_subject:,
    )

  let response = processor.process(payment, ctx)
  assert response == Ok(response.new(200) |> response.set_body(Fallback))
}
