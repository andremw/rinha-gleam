pub type ResponseTimeMs =
  Int

pub type Status {
  Status(failing: Bool, min_response_time: ResponseTimeMs)
}

pub type ProcessorsStatus {
  ProcessorsStatus(default: Status, fallback: Status)
}
