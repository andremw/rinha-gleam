import gleam/dynamic/decode
import wisp.{type Request}
import youid/uuid

pub type Body {
  Body(amount: Float, correlation_id: String)
}

fn body_decoder() -> decode.Decoder(Body) {
  use amount <- decode.field("amount", decode.float)
  use correlation_id <- decode.field("correlationId", decode.string)

  Body(amount:, correlation_id:)
  |> decode.success
}

pub fn handle_request(req: Request) {
  use json <- wisp.require_json(req)

  case decode.run(json, body_decoder()) {
    Ok(body) -> {
      case uuid.from_string(body.correlation_id) {
        Error(_) -> wisp.response(400)
        Ok(_) -> wisp.response(200)
      }
    }
    Error(_) -> wisp.response(400)
  }
}
