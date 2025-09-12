import birl
import gleam/dynamic/decode
import gleam/http
import gleam/http/response.{Response}
import gleam/result
import gleam/string_tree
import rinha_gleam/process_payment/context.{type Context}
import rinha_gleam/process_payment/processor
import rinha_gleam/shared/payment.{Payment}
import rinha_gleam/shared/payments_summary.{register_new_payment}
import wisp.{type Request}
import youid/uuid

pub type Body {
  Body(amount: Float, correlation_id: String)
}

pub type ProcessPaymentError {
  InvalidBodyError
  PaymentError
}

fn body_decoder() -> decode.Decoder(Body) {
  use amount <- decode.field("amount", decode.float)
  use correlation_id <- decode.field("correlationId", decode.string)

  Body(amount:, correlation_id:)
  |> decode.success
}

pub fn handle_request(req: Request, ctx: Context(payments_summary.Message)) {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)

  let processing_result = {
    use body <- result.try(
      decode.run(json, body_decoder())
      |> result.map_error(fn(_) { InvalidBodyError }),
    )

    use correlation_id <- result.try(
      uuid.from_string(body.correlation_id)
      |> result.map_error(fn(_) { InvalidBodyError }),
    )

    let payment =
      Payment(amount: body.amount, correlation_id:, requested_at: birl.now())

    processor.process(payment, ctx)
    |> result.map_error(fn(_) { PaymentError })
    |> result.map(fn(process_result) { #(process_result, payment) })
  }

  case processing_result {
    Error(InvalidBodyError) ->
      wisp.bad_request()
      |> wisp.set_body(
        wisp.Text(string_tree.append(string_tree.new(), "Invalid body!")),
      )
    Error(PaymentError) ->
      wisp.internal_server_error()
      |> wisp.set_body(
        wisp.Text(string_tree.append(
          string_tree.new(),
          "Failed to process payment",
        )),
      )
    Ok(#(Response(body: processor, ..), payment)) -> {
      let _ = register_new_payment(ctx.summary_subject, payment, processor:)
      // wisp.log_info("Payment successful")
      wisp.response(200)
    }
  }
}
