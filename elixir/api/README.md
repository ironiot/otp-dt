# Api
API Phoenix app for the OTP-DT project.

# Requirements
* A running db instance with a shortname.
  Must be set in environment so the app knows where to 
  connect to. Right now it is a shortname string in elixir/erlang.

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Export "DB_HOST" for the db shortname. 
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
