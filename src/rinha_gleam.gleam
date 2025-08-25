import gleam/erlang/process
import gleam/json
import mist
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()

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
    |> mist.port(9999)
    |> mist.start

  process.sleep_forever()
}
