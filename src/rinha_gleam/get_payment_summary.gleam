import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/string
import glyn/registry.{type Registry}
import rinha_gleam/shared/payments_summary
import wisp

pub type HttpClient {
  HttpClient(send: fn(Request(String)) -> Result(Response(String), Nil))
}

pub type Context(a) {
  Context(
    http_client: HttpClient,
    summary_subject: Registry(payments_summary.Message, Nil),
  )
}

pub fn handle_request(req: wisp.Request, ctx: Context(payments_summary.Message)) {
  use <- wisp.require_method(req, http.Get)

  // TODO: we might need to read the from/to params from qs
  case payments_summary.read(ctx.summary_subject) {
    Error(err) -> {
      wisp.log_error("Got error " <> string.inspect(err))
      wisp.internal_server_error()
    }
    Ok(summary) -> {
      wisp.log_info("Got payment summary: " <> string.inspect(summary))
      let encoded_summary =
        payments_summary.encode(summary) |> json.to_string_tree

      wisp.response(200)
      |> wisp.json_body(encoded_summary)
    }
  }
}
