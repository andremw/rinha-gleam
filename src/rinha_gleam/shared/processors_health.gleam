import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/otp/actor
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import glyn/registry

pub type ResponseTimeMs =
  Int

pub type Health {
  Health(failing: Bool, min_response_time: ResponseTimeMs)
}

pub type ProcessorsHealth {
  ProcessorsHealth(default: Health, fallback: Health)
}

pub const actor_name = "ProcessorsHealth"

pub type HttpClient {
  HttpClient(send: fn(Request(String)) -> Result(Response(String), Nil))
}

pub type MonitorArgs {
  MonitorArgs(
    http_client: HttpClient,
    processor_default_uri: Uri,
    processor_fallback_uri: Uri,
    check_interval_ms: Int,
  )
}

pub fn start_monitor(args: MonitorArgs) {
  // we create the registry that we'll register if it hasn't been registered by another instance yet.
  let registry =
    registry.new("healthcheck", message_decoder(args.http_client), Shutdown)

  let initial_state =
    ProcessorsHealth(
      default: Health(failing: False, min_response_time: 10),
      fallback: Health(failing: False, min_response_time: 10),
    )

  case
    actor.new_with_initialiser(200, fn(subject) {
      case registry.register(registry, actor_name, Nil) {
        // if registration fails, it means another instance already registered, so we just return the initialized actor
        Error(_) -> {
          actor.initialised(initial_state)
          |> actor.returning(subject)
          |> Ok
        }
        Ok(selector) -> {
          let selector =
            process.new_selector()
            |> process.select(subject)
            |> process.merge_selector(selector)

          actor.initialised(initial_state)
          |> actor.selecting(selector)
          |> actor.returning(subject)
          |> Ok
        }
      }
    })
    |> actor.on_message(handle_message)
    |> actor.start()
  {
    Error(_) -> registry
    Ok(started) -> {
      process.send(started.data, Check(started.data, args))

      registry
    }
  }
}

pub fn read(healthcheck_registry) {
  registry.call(healthcheck_registry, actor_name, 100, Read)
}

// actor (runs on different process)

pub type Processor {
  Default
  Fallback
}

pub type Message {
  Shutdown
  Read(client_process: Subject(ProcessorsHealth))
  Update(failing: Bool, min_response_time: Int, processor: Processor)
  Check(self: Subject(Message), monitor_args: MonitorArgs)
}

fn message_decoder(http_client) -> decode.Decoder(Message) {
  decode.one_of(decode.map(atom_decoder("shutdown"), fn(_) { Shutdown }), [
    read_decoder(),
    update_decoder(),
    check_decoder(http_client),
  ])
}

fn read_decoder() {
  use _ <- decode.field(0, atom_decoder("read"))
  use client_process <- decode.field(1, decode.dynamic)
  decode.success(Read(client_process: unsafe_cast_subject(client_process)))
}

fn update_decoder() {
  use _ <- decode.field(0, atom_decoder("update"))
  use failing <- decode.field(1, decode.bool)
  use min_response_time <- decode.field(2, decode.int)
  use processor <- decode.field(3, processor_decoder())
  decode.success(Update(failing:, min_response_time:, processor:))
}

fn processor_decoder() {
  decode.one_of(decode.map(atom_decoder("default"), fn(_) { Default }), [
    decode.map(atom_decoder("fallback"), fn(_) { Fallback }),
  ])
}

fn check_decoder(http_client) {
  use _ <- decode.field(0, atom_decoder("check"))
  use self <- decode.field(1, decode.dynamic)
  use processor_default_url <- decode.field(2, decode.string)
  use processor_fallback_url <- decode.field(3, decode.string)
  use check_interval_ms <- decode.field(4, decode.int)

  case uri.parse(processor_default_url), uri.parse(processor_fallback_url) {
    Ok(processor_default_uri), Ok(processor_fallback_uri) ->
      decode.success(Check(
        self: unsafe_cast_subject(self),
        monitor_args: MonitorArgs(
          check_interval_ms:,
          processor_default_uri:,
          processor_fallback_uri:,
          http_client:,
        ),
      ))
    _, _ -> todo
  }
}

fn atom_decoder(expected) {
  use value <- decode.then(atom.decoder())
  case atom.to_string(value) == expected {
    True -> decode.success(value)
    False -> decode.failure(value, "Expected atom: " <> expected)
  }
}

// Unsafe cast for Subject decoding - use with caution
@external(erlang, "gleam_stdlib", "identity")
fn unsafe_cast_subject(value: decode.Dynamic) -> Subject(a)

fn handle_message(state: ProcessorsHealth, message: Message) {
  case message {
    Shutdown -> actor.continue(state)

    Read(client_process) -> {
      // echo "READING " <> string.inspect(state)
      actor.send(client_process, state)
      actor.continue(state)
    }
    Check(self, args) -> {
      // echo "CHECKING? "
      // here we want to check both processors in parallel and then update them
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
      // echo "UPDATING? "
      case processor {
        Default ->
          ProcessorsHealth(
            ..state,
            default: Health(failing:, min_response_time:),
          )
        Fallback ->
          ProcessorsHealth(
            ..state,
            fallback: Health(failing:, min_response_time:),
          )
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
