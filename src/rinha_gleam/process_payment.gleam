import gleam/dynamic/decode
import gleam/http
import gleam/result
import rinha_gleam/process_payment/context.{type Context}
import wisp.{type Request}
import youid/uuid

pub type Body {
  Body(amount: Float, correlation_id: String)
}

pub type ProcessPaymentError {
  InvalidBodyError
}

fn body_decoder() -> decode.Decoder(Body) {
  use amount <- decode.field("amount", decode.float)
  use correlation_id <- decode.field("correlationId", decode.string)

  Body(amount:, correlation_id:)
  |> decode.success
}

pub fn handle_request(req: Request, _ctx: Context) {
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

    Ok(correlation_id)
  }

  case processing_result {
    Error(_) -> wisp.response(400)
    Ok(_) -> wisp.response(200)
  }
}
