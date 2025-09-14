import gleam/erlang/process.{type Subject}
import gleam/uri.{type Uri}
import rinha_gleam/shared/http_client.{type HttpClient}
import rinha_gleam/shared/processors_health.{type ProcessorsHealth}

pub type Context(a) {
  Context(
    http_client: HttpClient,
    processor_default_uri: Uri,
    processor_fallback_uri: Uri,
    processors_health: ProcessorsHealth,
    summary_subject: Subject(a),
  )
}
