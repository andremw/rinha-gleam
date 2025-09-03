pub type ResponseTimeMs =
  Int

pub type Health {
  Health(failing: Bool, min_response_time: ResponseTimeMs)
}

pub type ProcessorsHealth {
  ProcessorsHealth(default: Health, fallback: Health)
}
