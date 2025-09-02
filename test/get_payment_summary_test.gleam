import birl
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http/response
import gleam/json
import gleeunit
import glenvy/dotenv
import rinha_gleam/get_payment_summary.{Context, HttpClient}
import rinha_gleam/process_payment/processor/payments_summary.{
  PaymentsSummary, Totals,
}
import rinha_gleam/process_payment/processor/types.{Default, Fallback, Payment}
import wisp/testing
import youid/uuid

pub fn main() {
  gleeunit.main()
}

pub fn returns_the_accumulated_payment_summmary_test() {
  let _ = dotenv.load()
  let summary_subject = payments_summary.start()
  let correlation_id = uuid.v7()
  let requested_at = birl.now()

  // here we're not really interested in using the proper way to register a payment (through a request),
  // so it's no big deal to just register payments directly
  let _ =
    payments_summary.register_new_payment(
      summary_subject,
      Payment(amount: 19.9, correlation_id:, requested_at:),
      Default,
    )

  let _ =
    payments_summary.register_new_payment(
      summary_subject,
      Payment(amount: 15.0, correlation_id:, requested_at:),
      Fallback,
    )
  let _ =
    payments_summary.register_new_payment(
      summary_subject,
      Payment(amount: 10.0, correlation_id:, requested_at:),
      Fallback,
    )

  let request = testing.get("http://localhost:9999/payments-summary", [])

  let ctx =
    Context(
      http_client: HttpClient(send: fn(_req) { Ok(response.new(200)) }),
      summary_subject:,
    )

  // here we do want to test that the request is properly handled, so we don't access the actor directly otherwise we'd
  // be testing it instead of the slice
  let assert Ok(summary) = {
    let decoder = {
      let total_decoder = {
        use total_requests <- decode.field("totalRequests", decode.int)
        use total_amount <- decode.field("totalAmount", decode.float)
        decode.success(Totals(total_amount:, total_requests:))
      }

      use default <- decode.field("default", total_decoder)
      use fallback <- decode.field("fallback", total_decoder)

      decode.success(PaymentsSummary(default:, fallback:))
    }

    let assert Ok(string_body) =
      get_payment_summary.handle_request(request, ctx)
      |> testing.string_body
      |> dynamic.string
      |> decode.run(decode.string)

    json.parse(string_body, decoder)
  }

  assert summary
    == PaymentsSummary(
      default: Totals(total_requests: 1, total_amount: 19.9),
      fallback: Totals(total_requests: 2, total_amount: 25.0),
    )
}
