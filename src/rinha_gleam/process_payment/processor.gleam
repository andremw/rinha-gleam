import birl
import rinha_gleam/process_payment/decider.{type Decision}

import gleam/http
import gleam/http/request
import gleam/json
import gleam/result
import rinha_gleam/process_payment/context.{type Context, Context}

import rinha_gleam/shared/processor_types.{
  type PaymentProcessor, Default, Fallback,
}
import youid/uuid

pub fn process(
  decision: Decision,
  ctx: Context(a),
) -> Result(PaymentProcessor, Nil) {
  let Context(
    http_client: client,
    processor_default_uri: default_uri,
    processor_fallback_uri: fallback_uri,
    ..,
    // processors_health:,
  ) = ctx

  case decision {
    decider.PostponeDecision(decide_in:) -> todo
    decider.ProcessPaymentNow(processor:, payment:) -> {
      let body =
        json.object([
          #("amount", json.float(payment.amount)),
          #(
            "correlationId",
            json.string(uuid.to_string(payment.correlation_id)),
          ),
          #("requestedAt", json.string(birl.to_iso8601(payment.requested_at))),
        ])
        |> json.to_string

      use req <- result.try(case processor {
        Default -> prepare_req(default_uri, body)
        Fallback -> prepare_req(fallback_uri, body)
      })

      client.send(req)
      |> result.map(fn(_) { processor })
    }
  }
}

fn prepare_req(uri, body) {
  request.from_uri(uri)
  |> result.map(request.set_header(_, "content-type", "application/json"))
  |> result.map(request.set_path(_, "/payments"))
  |> result.map(request.set_method(_, http.Post))
  |> result.map(request.set_body(_, body))
}
