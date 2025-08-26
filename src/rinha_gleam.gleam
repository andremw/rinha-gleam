import envoy
import gleam/erlang/process
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
      fn(_req) {
        json.object([#("status", json.string("happy"))])
        |> json.to_string_tree
        |> wisp.json_response(200)
      },
      "",
    )
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.start

  process.sleep_forever()
}
