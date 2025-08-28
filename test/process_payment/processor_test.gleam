import birl
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/result
import gleam/string
import gleam/uri
import gleeunit
import glenvy/dotenv
import glenvy/env
import rinha_gleam/process_payment/context.{Context, HttpClient}
import rinha_gleam/process_payment/processor.{Payment}
import rinha_gleam/shared/processor_health.{ProcessorsStatus, Status}
import youid/uuid

pub fn main() {
  gleeunit.main()
}

fn setup() {
  let _ = dotenv.load()

  use default_url <- result.try(
    env.string("PROCESSOR_DEFAULT_URL")
    |> result.map_error(fn(_) { Nil }),
  )

  use fallback_url <- result.try(
    env.string("PROCESSOR_FALLBACK_URL")
    |> result.map_error(fn(_) { Nil }),
  )

  use default_uri <- result.try(uri.parse(default_url))
  use fallback_uri <- result.try(uri.parse(fallback_url))

  let amount = 10.5
  let correlation_id = uuid.v7()
  let requested_at = birl.now()
  let payment = Payment(amount:, correlation_id:, requested_at:)

  Ok(#(payment, default_uri, fallback_uri))
}

pub fn sends_a_request_to_default_payment_processor_test() {
  use #(payment, processor_default_uri, processor_fallback_uri) <- result.try(
    setup(),
  )

  let body =
    json.object([
      #("amount", json.float(payment.amount)),
      #("correlation_id", json.string(uuid.to_string(payment.correlation_id))),
      #("requested_at", json.string(birl.to_iso8601(payment.requested_at))),
    ])
    |> json.to_string

  use expected_request <- result.try(request.from_uri(processor_default_uri))

  let expected_request =
    expected_request
    |> request.set_method(http.Post)
    |> request.set_body(body)

  let http_client =
    context.HttpClient(send: fn(req) {
      assert req == expected_request
      response.new(200) |> Ok
    })

  let ctx =
    Context(
      http_client:,
      processor_default_uri:,
      processor_fallback_uri:,
      processors_status: ProcessorsStatus(
        default: Status(failing: False, min_response_time: 5),
        fallback: Status(failing: False, min_response_time: 5),
      ),
    )

  processor.process(payment, ctx)
}

pub fn sends_a_request_to_fallback_payment_processor_if_request_to_default_processor_fails_test() {
  use #(payment, processor_default_uri, processor_fallback_uri) <- result.try(
    setup(),
  )

  let http_client =
    HttpClient(send: fn(req) {
      // here we intentionally fail the request to the default processor
      case req.host |> string.contains("default") {
        True -> Error(Nil)
        False -> Ok(response.new(200))
      }
    })

  let ctx =
    Context(
      http_client:,
      processor_default_uri:,
      processor_fallback_uri:,
      processors_status: ProcessorsStatus(
        default: Status(failing: False, min_response_time: 5),
        fallback: Status(failing: False, min_response_time: 5),
      ),
    )

  let response = processor.process(payment, ctx)

  assert response == Ok(response.new(200))

  response
}

pub fn sends_a_direct_request_to_fallback_payment_processor_if_default_is_failing_test() {
  use #(payment, processor_default_uri, processor_fallback_uri) <- result.try(
    setup(),
  )

  let http_client =
    HttpClient(send: fn(req) {
      // here we intentionally fail the request to the default processor
      case req.host |> string.contains("default") {
        True -> Ok(response.new(200))
        // fallback responds with 202 just so we can differentiate
        False -> Ok(response.new(202))
      }
    })

  let ctx =
    Context(
      http_client:,
      processor_default_uri:,
      processor_fallback_uri:,
      processors_status: ProcessorsStatus(
        default: Status(failing: True, min_response_time: 5),
        fallback: Status(failing: False, min_response_time: 5),
      ),
    )

  let response = processor.process(payment, ctx)

  assert response == Ok(response.new(202))

  response
}
