import envoy
import gleam/erlang/process
import gleam/hackney
import gleam/int
import gleam/json
import gleam/result
import gleam/uri
import mist
import rinha_gleam/get_payment_summary
import rinha_gleam/process_payment
import rinha_gleam/process_payment/context.{Context}
import rinha_gleam/shared/http_client.{HttpClient}
import rinha_gleam/shared/payments_summary
import rinha_gleam/shared/processors_health
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
          // wisp.log_info("Sending request to " <> req.host)
          hackney.send(req) |> result.map_error(fn(_) { Nil })
        })

      let summary_subject = payments_summary.start()
      let healthcheck_subject =
        processors_health.start_monitor(processors_health.MonitorArgs(
          check_interval_ms: 5000,
          http_client:,
          processor_default_uri: default_uri,
          processor_fallback_uri: fallback_uri,
        ))

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
                // wisp.log_info("Health " <> string.inspect(processors_health))

                let ctx =
                  Context(
                    http_client:,
                    healthcheck_subject:,
                    processor_default_uri: default_uri,
                    processor_fallback_uri: fallback_uri,
                    summary_subject:,
                  )
                process_payment.handle_request(req, ctx)
              }
              ["payments-summary"] -> {
                let ctx =
                  get_payment_summary.Context(http_client:, summary_subject:)
                get_payment_summary.handle_request(req, ctx)
              }
              ["purge-payments"] -> {
                wisp.log_warning("PURGING PAYMENTS")
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
  }
}
