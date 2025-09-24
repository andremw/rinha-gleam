import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/json
import gleam/otp/actor
import gleam/result
import gleam/uri.{type Uri}
import rinha_gleam/shared/http_client.{type HttpClient}
import rinha_gleam/shared/processor.{type Processor, Default, Fallback}

pub type ResponseTimeMs =
  Int

pub type Health {
  Health(failing: Bool, min_response_time: ResponseTimeMs)
}

pub type ProcessorsHealth {
  ProcessorsHealth(default: Health, fallback: Health)
}

const actor_name = "ProcessorsHealth"

pub type MonitorArgs {
  MonitorArgs(
    http_client: HttpClient,
    processor_default_uri: Uri,
    processor_fallback_uri: Uri,
    check_interval_ms: Int,
  )
}

pub fn start_monitor(args: MonitorArgs) {
  let initial_state =
    ProcessorsHealth(
      default: Health(failing: False, min_response_time: 10),
      fallback: Health(failing: False, min_response_time: 10),
    )

  let name = process.new_name(actor_name)
  let _ =
    actor.new(initial_state)
    |> actor.on_message(handle_message)
    |> actor.named(name)
    |> actor.start()

  let monitor_process = process.named_subject(name)

  process.send(monitor_process, Check(monitor_process, args))

  monitor_process
}

pub fn read(subject) {
  process.call_forever(subject, Read)
}

// actor (runs on different process)

pub type Message {
  Shutdown
  Read(client_process: Subject(ProcessorsHealth))
  Update(failing: Bool, min_response_time: Int, processor: Processor)
  Check(self: Subject(Message), monitor_args: MonitorArgs)
}

fn handle_message(state: ProcessorsHealth, message: Message) {
  case message {
    Shutdown -> actor.continue(state)

    Read(client_process) -> {
      actor.send(client_process, state)
      actor.continue(state)
    }
    Check(self, args) -> {
      // here we want to check both processors in parallel and then update them
      // echo "running check"
      process.spawn_unlinked(fn() {
        use req <- result.try(request.from_uri(args.processor_default_uri))
        let req = req |> request.set_path("/payments/service-health")
        use res <- result.try(args.http_client.send(req))

        // echo "about to send check request to default"

        use health <- result.try(
          res.body
          |> json.parse(health_decoder())
          |> result.map_error(fn(_) { Nil }),
        )

        // echo "sending Update for default"

        process.send(
          self,
          Update(
            failing: health.failing,
            min_response_time: health.min_response_time,
            processor: Default,
          ),
        )
        |> Ok
      })

      process.spawn_unlinked(fn() {
        use req <- result.try(request.from_uri(args.processor_fallback_uri))
        let req = req |> request.set_path("/payments/service-health")
        use res <- result.try(args.http_client.send(req))

        // echo "about to send check request to fallback"
        use health <- result.try(
          res.body
          |> json.parse(health_decoder())
          |> result.map_error(fn(_) { Nil }),
        )

        // echo "sending Update for fallback"

        process.send(
          self,
          Update(
            failing: health.failing,
            min_response_time: health.min_response_time,
            processor: Fallback,
          ),
        )
        |> Ok
      })

      process.send_after(self, args.check_interval_ms, Check(self, args))

      actor.continue(state)
    }
    Update(failing:, min_response_time:, processor:) -> {
      // echo "Update running for " <> string.inspect(processor)
      case processor {
        Default ->
          ProcessorsHealth(
            ..state,
            default: Health(failing:, min_response_time:),
          )
        // |> echo
        Fallback ->
          ProcessorsHealth(
            ..state,
            fallback: Health(failing:, min_response_time:),
          )
        // |> echo
      }
      |> actor.continue
    }
  }
}

fn health_decoder() -> decode.Decoder(Health) {
  use failing <- decode.field("failing", decode.bool)
  use min_response_time <- decode.field("minResponseTime", decode.int)

  decode.success(Health(failing:, min_response_time:))
}
