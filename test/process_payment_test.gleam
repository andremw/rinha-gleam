import gleam/http/response
import gleam/json
import gleam/result
import gleam/uri
import gleeunit
import glenvy/dotenv
import glenvy/env
import rinha_gleam/process_payment
import rinha_gleam/process_payment/context.{Context, HttpClient}
import rinha_gleam/shared/processor_health.{ProcessorsStatus, Status}
import wisp/testing
import youid/uuid

pub fn main() -> Nil {
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

  let status = Status(failing: False, min_response_time: 5)
  Ok(Context(
    http_client: HttpClient(send: fn(_req) { Ok(response.new(200)) }),
    processor_default_uri: default_uri,
    processor_fallback_uri: fallback_uri,
    processors_status: ProcessorsStatus(default: status, fallback: status),
  ))
}

pub fn handler_returns_a_simple_response_test() {
  let uuid = uuid.v4() |> uuid.to_string
  let body =
    json.object([
      #("amount", json.float(19.9)),
      #("correlationId", json.string(uuid)),
    ])

  let request = testing.post_json("http://localhost:9999/payments", [], body)

  use ctx <- result.try(setup())

  let response = process_payment.handle_request(request, ctx)

  assert response.status == 200
  Ok("")
}

pub fn handler_requires_amount_test() {
  let body = json.object([#("correlationId", json.string(""))])

  let request = testing.post_json("http://localhost:9999/payments", [], body)
  use ctx <- result.try(setup())
  let response = process_payment.handle_request(request, ctx)

  assert response.status == 400
  Ok("")
}

pub fn handler_requires_correlation_id_uuid_test() {
  let body =
    json.object([
      #("amount", json.float(19.9)),
      #("correlationId", json.string("")),
    ])
  let request = testing.post_json("http://localhost:9999/payments", [], body)
  use ctx <- result.try(setup())
  let response = process_payment.handle_request(request, ctx)

  assert response.status == 400
  Ok("")
}
