import birl
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/uri
import gleeunit
import glenvy/dotenv
import glenvy/env
import rinha_gleam/process_payment/context.{Context}
import rinha_gleam/process_payment/processor
import rinha_gleam/shared/http_client.{HttpClient}
import rinha_gleam/shared/payment.{Payment}
import rinha_gleam/shared/processor_types.{Default}
import youid/uuid

pub fn main() {
  gleeunit.main()
}

fn setup() {
  let _ = dotenv.load()

  let assert Ok(default_url) = env.string("PROCESSOR_DEFAULT_URL")
  let assert Ok(fallback_url) = env.string("PROCESSOR_FALLBACK_URL")
  let assert Ok(default_uri) = uri.parse(default_url)
  let assert Ok(fallback_uri) = uri.parse(fallback_url)

  let amount = 10.5
  let correlation_id = uuid.v7()
  let requested_at = birl.now()
  let payment = Payment(amount:, correlation_id:, requested_at:)

  #(payment, default_uri, fallback_uri)
}

pub fn sends_a_request_to_default_payment_processor_test() {
  let #(payment, processor_default_uri, processor_fallback_uri) = setup()

  let body =
    json.object([
      #("amount", json.float(payment.amount)),
      #("correlationId", json.string(uuid.to_string(payment.correlation_id))),
      #("requestedAt", json.string(birl.to_iso8601(payment.requested_at))),
    ])
    |> json.to_string

  let assert Ok(expected_request) = request.from_uri(processor_default_uri)
  let expected_request = expected_request |> request.set_path("/payments")

  let expected_request =
    expected_request
    |> request.set_header("content-type", "application/json")
    |> request.set_method(http.Post)
    |> request.set_body(body)

  let http_client =
    HttpClient(send: fn(req) {
      assert req == expected_request
      response.new(200) |> Ok
    })

  let summary_subject = process.new_subject()
  let healthcheck_subject = process.new_subject()

  let ctx =
    Context(
      http_client:,
      processor_default_uri:,
      processor_fallback_uri:,
      healthcheck_subject:,
      summary_subject:,
    )

  let response = processor.process(#(payment, Default), ctx)

  assert response == Ok(Default)
}
