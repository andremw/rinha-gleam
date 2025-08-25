import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import logging
import mist

pub fn main() -> Nil {
  logging.configure()
  logging.set_level(logging.Debug)

  logging.log(logging.Info, "Starting server")

  let not_found =
    response.new(404) |> response.set_body(mist.Bytes(bytes_tree.new()))

  let assert Ok(_) =
    mist.new(fn(req) {
      logging.log(logging.Info, "Got request: ")

      case request.path_segments(req) {
        [] ->
          response.new(200)
          |> response.set_body(mist.Bytes(bytes_tree.from_string("Ok")))

        _ -> not_found
      }
    })
    |> mist.bind("localhost")
    |> mist.with_ipv6
    |> mist.port(9999)
    |> mist.start

  process.sleep_forever()
}
