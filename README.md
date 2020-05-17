# Pretty

<!-- MDOC !-->
Inspect values with syntax colors despite your remote console.

This module addresses two surprises you'll encounter trying to dump data to the remote console
like you did during development with `iex -S mix`:

* `IO.inspect/1` _et al_ work fine at the `iex>` prompt but somehow not when called from a
  `:telemetry` handler function or other troubleshooting mechanism… unless you think to
  look at the log output

* The syntax colors aren't working like you think they should, either

* The inspection width is 80… just like `iex`, now that you think of it

Why? See the [explanation](EXPLAIN.md).

In case of emergency, **BREAK GLASS** (see below) to get what you need with some copying and
pasting.

## Usage

To get the right syntax colors and inspection width, replace your calls to `IO.inspect/1` with
calls to `Pretty.inspect/1`:

```elixir
Pretty.inspect(<<0, 1, 2>>, width: 40)
```

… and `IO.inspect/2` with `Pretty.inspect/2`:

```elixir
[1, 2, 3]
|> Pretty.inspect(label: "before")
|> Enum.map(&(&1 * 2))
|> Pretty.inspect(label: "after")
|> Enum.sum()
```

To get the right colors, width, and output device, use `Pretty.bind/1` to get an `t:inspector/1`
function, and use it instead of `IO.inspect/1` or `Pretty.inspect/1`:

```elixir
dump = Pretty.bind(label: "Ecto")
handler = fn name, m10s, m6a, nil -> dump.({name, m10s, m6a}) end
:telemetry.attach(self(), [:my_app, :repo, :query], handler, nil)
```

## BREAK GLASS

If you're sitting at a remote console _right now_ and just need some output without taking a new
dependency and re-releasing, paste this in to get most of the functionality of `Pretty.bind/1`
right away:

```elixir
bind = fn opts ->
  device = Process.group_leader()
  width = with {:ok, n} <- :io.columns(device), do: n, else: (_ -> %Inspect.Opts{}.width)
  opts = Keyword.merge(:rpc.call(:erlang.node(device), IEx.Config, :inspect_opts, []), opts)
  opts = Keyword.merge(opts, pretty: true, width: width)
  reset = Enum.find_value(Keyword.get(opts, :syntax_colors, []), [], fn _ -> IO.ANSI.reset() end)
  fn term -> IO.puts(device, [Kernel.inspect(term, opts), reset]); term end
end
# I never said it'd be Pretty...
# Can you make it shorter? PR or it didn't happen.
```

… and then use that:

```elixir
dump = bind.(label: "ecto")
handler = fn name, m10s, m6a, nil -> dump.({name, m10s, m6a}) end
:telemetry.attach(self(), [:my_app, :repo, :query], handler, nil)
```

What's going on? See the [explanation](EXPLAIN.md).

<!-- MDOC !-->
## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed by adding
`pretty` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pretty, "~> 1.0.0"}
  ]
end
```

## Development

`make check` before you commit! Otherwise:

* `mix deps.get` to get your dependencies
* `mix deps.compile` to compile them
* `mix compile` to compile your code
* `mix credo` to suggest more idiomatic style for it
* `mix dialyzer` to find problems static typing might spot… *slowly*
* `mix test` to run unit tests
* `mix test.watch` to run the tests again whenever you change something
* `mix coveralls` to check test coverage
* `touch lib/pretty.ex && mix docs` to generate documentation for this project
* `mix help` to find out what else you can do with `mix`
