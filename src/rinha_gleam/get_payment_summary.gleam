import birl
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import rinha_gleam/shared/http_client.{type HttpClient}
import rinha_gleam/shared/payments_summary
import wisp

pub type Context(a) {
  Context(http_client: HttpClient, summary_subject: Subject(a))
}

pub fn handle_request(req: wisp.Request, ctx: Context(payments_summary.Message)) {
  use <- wisp.require_method(req, http.Get)

  let params = wisp.get_query(req)
  let from =
    list.key_find(params, "from")
    |> result.map(string.replace(_, " ", "+"))
    |> result.try(birl.parse)
    |> option.from_result
  let to =
    list.key_find(params, "to")
    |> result.map(string.replace(_, " ", "+"))
    |> result.try(birl.parse)
    |> option.from_result

  let summary = payments_summary.read(ctx.summary_subject, from:, to:)
  // wisp.log_info("Returning summary: " <> string.inspect(summary))
  let encoded_summary = payments_summary.encode(summary) |> json.to_string_tree

  wisp.response(200)
  |> wisp.json_body(encoded_summary)
}
