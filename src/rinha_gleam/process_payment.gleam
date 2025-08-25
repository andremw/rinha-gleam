import gleam/dynamic/decode
import wisp.{type Request}

pub type Body {
  Body(amount: Float)
}

fn body_decoder() -> decode.Decoder(Body) {
  use amount <- decode.field("amount", decode.float)

  Body(amount:)
  |> decode.success
}

pub fn handle_request(req: Request) {
  use json <- wisp.require_json(req)

  case decode.run(json, body_decoder()) {
    Ok(_) -> wisp.response(200)
    Error(_) -> wisp.response(400)
  }
}
