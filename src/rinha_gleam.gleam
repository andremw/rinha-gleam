import envoy
import gleam/erlang/process
import gleam/http
import gleam/int
import gleam/json
import gleam/result
import mist
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()

  let port = envoy.get("PORT") |> result.try(int.parse) |> result.unwrap(9999)

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
          ["payments"] -> {
            use <- wisp.require_method(req, http.Post)

            wisp.ok()
          }
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
