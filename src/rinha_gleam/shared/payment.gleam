import birl.{type Time}
import youid/uuid.{type Uuid}

pub type Payment {
  Payment(amount: Float, correlation_id: Uuid, requested_at: Time)
}
