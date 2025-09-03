// import gleam/erlang/process
import gleeunit

// import rinha_gleam/shared/processors_health.{Health, ProcessorsHealth}

pub fn main() {
  gleeunit.main()
}
// pub fn keeps_track_of_processors_health_test() {
//   let monitor = processors_health.start_monitor()
//   let initial_check = processors_health.read(monitor)
//   process.sleep(20)
//   let second_check = processors_health.read(monitor)

//   assert [initial_check, second_check]
//     == [
//       ProcessorsHealth(
//         default: Health(failing: False, min_response_time: 10),
//         fallback: Health(failing: False, min_response_time: 50),
//       ),
//       ProcessorsHealth(
//         default: Health(failing: False, min_response_time: 10),
//         fallback: Health(failing: False, min_response_time: 50),
//       ),
//     ]
// }
