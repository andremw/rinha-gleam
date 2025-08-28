import gleam/http/response
import gleam/json
import gleam/uri
import gleeunit
import rinha_gleam/process_payment
import rinha_gleam/process_payment/context.{Context, HttpClient}
import rinha_gleam/shared/processor_health.{ProcessorsStatus, Status}
import wisp/testing
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn handler_returns_a_simple_response_test() {
  let uuid = uuid.v4() |> uuid.to_string
  let body =
    json.object([
      #("amount", json.float(19.9)),
      #("correlationId", json.string(uuid)),
    ])

  let request = testing.post_json("http://localhost:9999/payments", [], body)
  let status = Status(failing: False, min_response_time: 5)
  let ctx =
    Context(
      http_client: HttpClient(send: fn(_req) { Ok(response.new(200)) }),
      processor_default_uri: uri.empty,
      processor_fallback_uri: uri.empty,
      processors_status: ProcessorsStatus(default: status, fallback: status),
    )

  let response = process_payment.handle_request(request, ctx)

  assert response.status == 200
}

pub fn handler_requires_amount_test() {
  let body = json.object([#("correlationId", json.string(""))])

  let request = testing.post_json("http://localhost:9999/payments", [], body)
  let status = Status(failing: False, min_response_time: 5)
  let ctx =
    Context(
      http_client: HttpClient(send: fn(_req) { Ok(response.new(200)) }),
      processor_default_uri: uri.empty,
      processor_fallback_uri: uri.empty,
      processors_status: ProcessorsStatus(default: status, fallback: status),
    )
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
  let status = Status(failing: False, min_response_time: 5)
  let ctx =
    Context(
      http_client: HttpClient(send: fn(_req) { Ok(response.new(200)) }),
      processor_default_uri: uri.empty,
      processor_fallback_uri: uri.empty,
      processors_status: ProcessorsStatus(default: status, fallback: status),
    )
  let response = process_payment.handle_request(request, ctx)

  assert response.status == 400
}
