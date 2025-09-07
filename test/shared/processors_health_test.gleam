import gleam/erlang/process
import gleam/http/response.{Response}
import gleam/json
import gleam/string
import gleam/uri
import gleeunit
import glenvy/env
import rinha_gleam/shared/processors_health.{
  type Health, Health, HttpClient, MonitorArgs, ProcessorsHealth,
}

pub fn main() {
  gleeunit.main()
}

pub fn keeps_track_of_processors_health_test() {
  let assert Ok(default_url) = env.string("PROCESSOR_DEFAULT_URL")
  let assert Ok(fallback_url) = env.string("PROCESSOR_FALLBACK_URL")
  let assert Ok(default_uri) = uri.parse(default_url)
  let assert Ok(fallback_uri) = uri.parse(fallback_url)

  let http_client =
    HttpClient(send: fn(req) {
      let health = {
        case req.host |> string.contains("default") {
          True -> Health(failing: True, min_response_time: 1500)
          False -> Health(failing: False, min_response_time: 10)
        }
      }

      health
      |> encode_health
      |> json.to_string
      |> Response(200, [], _)
      |> Ok
    })

  let monitor =
    processors_health.start_monitor(MonitorArgs(
      check_interval_ms: 10,
      http_client:,
      processor_default_uri: default_uri,
      processor_fallback_uri: fallback_uri,
    ))

  // echo "before initial_check"
  let initial_check = processors_health.read(monitor)
  // echo "after initial check"
  process.sleep(20)
  // echo "before second check"
  let second_check = processors_health.read(monitor)
  // echo "after second check"

  assert [initial_check, second_check]
    == [
      ProcessorsHealth(
        default: Health(failing: False, min_response_time: 10),
        fallback: Health(failing: False, min_response_time: 10),
      ),
      ProcessorsHealth(
        default: Health(failing: True, min_response_time: 1500),
        fallback: Health(failing: False, min_response_time: 10),
      ),
    ]

  monitor
  |> process.send(processors_health.Shutdown)
}

fn encode_health(health: Health) {
  json.object([
    #("failing", json.bool(health.failing)),
    #("minResponseTime", json.int(health.min_response_time)),
  ])
}
