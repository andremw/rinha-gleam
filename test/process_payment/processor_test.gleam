import birl
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleeunit
import rinha_gleam/process_payment/processor.{HttpClient, Payment}
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn sends_a_request_to_default_payment_processor_test() {
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

  let expected_request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_body(body)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_scheme(http.Http)
    |> request.set_host("blabla.com")
    |> request.set_path("/bla")

  let client =
    HttpClient(send: fn(req) {
      assert req == expected_request
      response.new(200) |> Ok
    })

  processor.process(payment, client)
}
// pub fn sends_a_request_to_fallback_payment_processor_if_request_to_default_processor_fails() {
//   todo
// }
// pub fn sends_a_direct_request_to_fallback_payment_processor_if_default_is_failing() {
//   todo
// }
