import birl.{type Time}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/result
import gleam/uri
import glenvy/dotenv
import glenvy/env
import youid/uuid.{type Uuid}

pub type Payment {
  Payment(amount: Float, correlation_id: Uuid, requested_at: Time)
}

pub type HttpClient {
  HttpClient(send: fn(Request(String)) -> Result(Response(String), Nil))
}

pub fn process(
  payment: Payment,
  client: HttpClient,
) -> Result(Response(String), Nil) {
  let _ = dotenv.load()
  use processor_url <- result.try(
    env.string("PROCESSOR_DEFAULT_URL")
    |> result.map_error(fn(_) { Nil }),
  )

  use uri <- result.try(uri.parse(processor_url))
  use request <- result.try(request.from_uri(uri))

  let body =
    json.object([
      #("amount", json.float(payment.amount)),
      #("correlation_id", json.string(uuid.to_string(payment.correlation_id))),
      #("requested_at", json.string(birl.to_iso8601(payment.requested_at))),
    ])
    |> json.to_string

  request
  |> request.set_method(http.Post)
  |> request.set_body(body)
  |> client.send
}
