# Api

API Phoenix app for the OTP-DT project.

## Usage

- Run `mix setup` to install and setup dependencies
- Start the DB instance. Follow instructions in `../database/readme.md`.
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

# Adding a Route
To add a route, the path must be present in
`lib/api_web/router.ex`, and 
`lib/api_web/controllers/api_json.ex`, which executes
the GenServer calls to the DB.
The calls can be found in `lib/api/worker.ex`.

