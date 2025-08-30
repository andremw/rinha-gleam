import envoy
import gleam/erlang/process
import gleam/hackney
import gleam/int
import gleam/json
import gleam/result
import gleam/uri
import mist
import rinha_gleam/process_payment
import rinha_gleam/process_payment/context.{Context, HttpClient}
import rinha_gleam/shared/processor_health.{ProcessorsStatus, Status}
import wisp
import wisp/wisp_mist

fn get_processor_uris() {
  use default_url <- result.try(envoy.get("PROCESSOR_DEFAULT_URL"))
  use fallback_url <- result.try(envoy.get("PROCESSOR_FALLBACK_URL"))

  use default_uri <- result.try(uri.parse(default_url))
  use fallback_uri <- result.try(uri.parse(fallback_url))

  Ok(#(default_uri, fallback_uri))
}

pub fn main() -> Nil {
  wisp.configure_logger()

  case get_processor_uris() {
    Error(_) -> Nil
    Ok(#(default_uri, fallback_uri)) -> {
      let port =
        envoy.get("PORT") |> result.try(int.parse) |> result.unwrap(9999)

      let http_client =
        HttpClient(send: fn(req) {
          wisp.log_info("Sending request to " <> req.host)
          hackney.send(req) |> result.map_error(fn(_) { Nil })
        })

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
                let processors_status =
                  ProcessorsStatus(
                    default: Status(failing: False, min_response_time: 5),
                    fallback: Status(failing: False, min_response_time: 5),
                  )

                let ctx =
                  Context(
                    http_client:,
                    processors_status:,
                    processor_default_uri: default_uri,
                    processor_fallback_uri: fallback_uri,
                  )
                process_payment.handle_request(req, ctx)
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
  }
}
