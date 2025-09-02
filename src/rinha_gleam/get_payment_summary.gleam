import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import rinha_gleam/process_payment/processor/payments_summary
import wisp

pub type HttpClient {
  HttpClient(send: fn(Request(String)) -> Result(Response(String), Nil))
}

pub type Context(a) {
  Context(http_client: HttpClient, summary_subject: Subject(a))
}

pub fn handle_request(req: wisp.Request, ctx: Context(payments_summary.Message)) {
  use <- wisp.require_method(req, http.Get)

  // TODO: we might need to read the from/to params from qs
  let summary = payments_summary.read(ctx.summary_subject)
  let encoded_summary = payments_summary.encode(summary) |> json.to_string_tree

  wisp.response(200)
  |> wisp.json_body(encoded_summary)
}
