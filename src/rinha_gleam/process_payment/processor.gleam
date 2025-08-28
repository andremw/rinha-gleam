import birl.{type Time}
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/json
import gleam/result
import rinha_gleam/process_payment/context.{
  type Context, type HttpClient, Context,
}
import youid/uuid.{type Uuid}

pub type Payment {
  Payment(amount: Float, correlation_id: Uuid, requested_at: Time)
}

pub fn process(payment: Payment, ctx: Context) -> Result(Response(String), Nil) {
  let Context(
    http_client: client,
    processor_default_uri: default_uri,
    processor_fallback_uri: fallback_uri,
    processors_status:,
  ) = ctx

  let body =
    json.object([
      #("amount", json.float(payment.amount)),
      #("correlation_id", json.string(uuid.to_string(payment.correlation_id))),
      #("requested_at", json.string(birl.to_iso8601(payment.requested_at))),
    ])
    |> json.to_string

  use default_req <- result.try(prepare_req(default_uri, body))
  use fallback_req <- result.try(prepare_req(fallback_uri, body))

  case processors_status.default.failing {
    False ->
      send_with_recovery(client, primary: default_req, secondary: fallback_req)
    True -> {
      fallback_req
      |> client.send
    }
  }
}

fn prepare_req(uri, body) {
  request.from_uri(uri)
  |> result.map(request.set_method(_, http.Post))
  |> result.map(request.set_body(_, body))
}

fn send_with_recovery(client: HttpClient, primary req, secondary fallback) {
  req
  |> client.send
  |> result.try_recover(fn(_) {
    fallback
    |> client.send
  })
}
