import Config

config :ex4j, Bolt,
  url: "bolt://127.0.0.1:7687",
  auth: [username: "neo4j", password: "zEb0zryxK62NNRXKWxJKd7qeEFkO3mLIgcGwuUA4lvg"],
  pool_size: 2,
  ssl: false
