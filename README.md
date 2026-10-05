# OtpDt
Implementing digital twins using Elixir and the OTP framework

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `otp_dt` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:otp_dt, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/otp_dt>.

## Architecture
There are two proposed architectures for the project.
![System architecture](system-arch.png)

![System architecture from statement of work](system-arch-sow.png)

## TODOs
- [] Revamp the architecture to be more compatible with
     Elixir's module, `GenServer`, and `Supervisor` patterns.
- [] Implement two systems, one in Elixir and the other
     in Golang for comparison.
     - [] Instantiate TimescaleDB
     - [] Parse `protobuf` data into language-appropriate
          structures
     
- [] Provide an interface for presentation. At the minumum
     there should be an API and a CLI, but for presentation
     a graphical front-end may be needed.
- [] Analysis paper as an end deliverable. Can use $\LaTeX$ to
     write the paper.

Send a private message to the collaborators for access to Trello.



