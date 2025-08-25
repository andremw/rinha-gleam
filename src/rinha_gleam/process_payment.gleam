import gleam/http/request.{type Request}
import gleam/http/response.{Response}

pub fn handle_request(_request: Request(a)) {
  Response(200, [], [])
}
