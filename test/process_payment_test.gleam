import gleam/http/request
import gleam/json
import gleeunit
import rinha_gleam/process_payment

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn process_payment_handler_returns_a_simple_response_test() {
  let assert Ok(request) = request.to("http://localhost:9999/payments")

  let body = json.object([#("amount", json.float(19.9))]) |> json.to_string

  let response =
    request
    |> request.set_body(body)
    |> request.prepend_header("Content-Type", "application/json")
    |> process_payment.handle_request

  assert response.status == 200
}
