import envoy
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/result
import mist
import rinha_gleam/process_payment
import rinha_gleam/process_payment/context.{Context}
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()

  let port = envoy.get("PORT") |> result.try(int.parse) |> result.unwrap(9999)
  let ctx =
    Context(
      http_client: todo,
      processor_default_uri: todo,
      processor_fallback_uri: todo,
      processors_status: todo,
    )

  let assert Ok(_) =
    wisp_mist.handler(
      fn(req) {
        case wisp.path_segments(req) {
          // matches /
          [] ->
            json.object([#("status", json.string("happyy"))])
            |> json.to_string_tree
            |> wisp.json_response(200)
          // matches /payments
          ["payments"] -> process_payment.handle_request(req, ctx)
          _ -> wisp.not_found()
        }
      },
      "",
    )
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.start

  process.sleep_forever()
}
