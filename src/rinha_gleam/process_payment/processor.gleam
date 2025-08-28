import birl.{type Time}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/result
import gleam/uri.{type Uri}
import rinha_gleam/shared/processor_health.{type ProcessorsStatus}
import youid/uuid.{type Uuid}

pub type Payment {
  Payment(amount: Float, correlation_id: Uuid, requested_at: Time)
}

pub type HttpClient {
  HttpClient(send: fn(Request(String)) -> Result(Response(String), Nil))
}

pub type Context {
  Context(
    http_client: HttpClient,
    processor_default_uri: Uri,
    processor_fallback_uri: Uri,
    processor_status: ProcessorsStatus,
  )
}

pub fn process(payment: Payment, ctx: Context) -> Result(Response(String), Nil) {
  let Context(
    http_client: client,
    processor_default_uri: processor_uri,
    processor_fallback_uri: fallback_uri,
    processor_status: _p,
  ) = ctx

  use request <- result.try(request.from_uri(processor_uri))

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
  |> result.try_recover(fn(_) {
    use request <- result.try(request.from_uri(fallback_uri))

    request
    |> request.set_method(http.Post)
    |> request.set_body(body)
    |> client.send
  })
}
