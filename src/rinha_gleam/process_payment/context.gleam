import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/uri.{type Uri}
import glyn/registry.{type Registry}
import rinha_gleam/shared/payments_summary
import rinha_gleam/shared/processors_health.{type ProcessorsHealth}

pub type HttpClient {
  HttpClient(send: fn(Request(String)) -> Result(Response(String), Nil))
}

pub type Context(a) {
  Context(
    http_client: HttpClient,
    processor_default_uri: Uri,
    processor_fallback_uri: Uri,
    processors_health: ProcessorsHealth,
    summary_subject: Registry(payments_summary.Message, Nil),
  )
}
