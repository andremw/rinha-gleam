import gleam/json
import gleeunit
import rinha_gleam/process_payment
import wisp/testing
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn process_payment_handler_returns_a_simple_response_test() {
  let uuid = uuid.v4() |> uuid.to_string
  let body =
    json.object([
      #("amount", json.float(19.9)),
      #("correlationId", json.string(uuid)),
    ])

  let request = testing.post_json("http://localhost:9999/payments", [], body)
  let response = process_payment.handle_request(request)

  assert response.status == 200
}

pub fn process_payment_handler_requires_amount_test() {
  let body = json.object([#("correlationId", json.string(""))])

  let request = testing.post_json("http://localhost:9999/payments", [], body)
  let response = process_payment.handle_request(request)

  assert response.status == 400
}

pub fn process_payment_handler_requires_correlation_id_uuid_test() {
  let body =
    json.object([
      #("amount", json.float(19.9)),
      #("correlationId", json.string("")),
    ])
  let request = testing.post_json("http://localhost:9999/payments", [], body)
  let response = process_payment.handle_request(request)

  assert response.status == 400
}
