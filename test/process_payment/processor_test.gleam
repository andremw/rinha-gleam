import birl
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/result
import gleam/uri
import gleeunit
import glenvy/dotenv
import glenvy/env
import rinha_gleam/process_payment/processor.{HttpClient, Payment}
import youid/uuid

pub fn main() {
  gleeunit.main()
}

pub fn sends_a_request_to_default_payment_processor_test() {
  let _ = dotenv.load()

  let amount = 10.5
  let correlation_id = uuid.v7()
  let requested_at = birl.now()
  let payment = Payment(amount:, correlation_id:, requested_at:)

  let body =
    json.object([
      #("amount", json.float(amount)),
      #("correlation_id", json.string(uuid.to_string(correlation_id))),
      #("requested_at", json.string(birl.to_iso8601(requested_at))),
    ])
    |> json.to_string

  use processor_url <- result.try(
    env.string("PROCESSOR_DEFAULT_URL")
    |> result.map_error(fn(_) { Nil }),
  )

  use uri <- result.try(uri.parse(processor_url))

  use expected_request <- result.try(request.from_uri(uri))

  let expected_request =
    expected_request
    |> request.set_method(http.Post)
    |> request.set_body(body)

  let http_client =
    HttpClient(send: fn(req) {
      assert req == expected_request
      response.new(200) |> Ok
    })

  let ctx = processor.Context(http_client:, processor_default_uri: uri)

  processor.process(payment, ctx)
}
// pub fn sends_a_request_to_fallback_payment_processor_if_request_to_default_processor_fails() {
//   todo
// }
// pub fn sends_a_direct_request_to_fallback_payment_processor_if_default_is_failing() {
//   todo
// }
