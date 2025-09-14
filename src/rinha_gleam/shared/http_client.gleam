import gleam/http/request.{type Request}
import gleam/http/response.{type Response}

pub type HttpClient {
  HttpClient(send: fn(Request(String)) -> Result(Response(String), Nil))
}
