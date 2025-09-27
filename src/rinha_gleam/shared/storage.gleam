// import gleam/erlang/process
// import gleam/option.{Some}
// import gleam/otp/static_supervisor as supervisor
// import gleam/result
// import valkyrie

// pub type Connection =
//   valkyrie.Connection

// const timeout = 2000

// pub fn start() -> Connection {
//   let pool_name = process.new_name("pool")

//   // Define a pool of 10 connections to the default Redis instance on localhost.
//   let valkyrie_child_spec =
//     valkyrie.Config(..valkyrie.default_config(), host: "redis")
//     |> valkyrie.supervised_pool(size: 1000, name: Some(pool_name), timeout:)

//   // Start the pool under a supervisor
//   let assert Ok(_started) =
//     supervisor.new(supervisor.OneForOne)
//     |> supervisor.add(valkyrie_child_spec)
//     |> supervisor.start

//   // Get the connection now that the pool is started
//   valkyrie.named_connection(pool_name)
// }

// pub fn rpop(conn conn, key key) {
//   valkyrie.llen(conn, key, timeout)
//   |> result.try(valkyrie.rpop(conn, key, _, timeout))
// }

// pub fn lpush(conn conn, key key, value value) {
//   valkyrie.lpush(conn, key, [value], timeout)
// }

// pub fn clear(conn conn, key key) {
//   valkyrie.del(conn, [key], timeout)
// }
