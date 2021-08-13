# Pretty

[![Build status badge](https://github.com/amplifiedai/pretty/workflows/Elixir%20CI/badge.svg)](https://github.com/amplifiedai/pretty/actions)
[![Module Version](https://img.shields.io/hexpm/v/pretty.svg)](https://hex.pm/packages/pretty)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/pretty/)
[![Total Download](https://img.shields.io/hexpm/dt/pretty.svg)](https://hex.pm/packages/pretty)
[![License](https://img.shields.io/hexpm/l/pretty.svg)](https://github.com/amplifiedai/pretty/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/amplifiedai/pretty.svg)](https://github.com/amplifiedai/pretty/commits/master)


<!-- MDOC -->
<!-- INCLUDE -->
Inspect values with syntax colors despite your remote console.

This module addresses two surprises you'll encounter trying to dump data to the remote console
like you did during development with `iex -S mix`:

* `IO.inspect/1` _et al_ work fine at the `iex>` prompt but somehow not when called from a
  `:telemetry` handler function or other troubleshooting mechanism… unless you think to
  look at the log output

* The syntax colors aren't working like you think they should, either

* The inspection width is 80… just like `iex`, now that you think of it

Why? See the [explanation](#explanation).

In case of emergency, **[BREAK GLASS](#break-glass)** to get what you need with some copying and
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

What's going on? See the [explanation](#explanation).

<!-- MDOC -->
## Installation

Add `:pretty` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pretty, "~> 1.0.0"}
  ]
end
```

## Development

`make check` before you commit! If you'd prefer to do it manually:

* `mix do deps.get, deps.unlock --unused, deps.clean --unused` if you change dependencies
* `mix compile --warnings-as-errors` for a stricter compile
* `mix coveralls.html` to check for test coverage
* `mix credo` to suggest more idiomatic style for your code
* `mix dialyzer` to find problems typing might reveal… albeit *slowly*
* `mix docs` to generate documentation

<!-- MDOC -->
<!-- INCLUDE -->
## <!--module-->Explanation

## The Case of the Missing Output

Hooking up telemetry to `Ecto.Adapters.SQL` to watch your requests in action works from
the `iex -S mix phx.server` prompt, but when you do it on a remote console you only see output for
requests you made at the prompt:

```elixir
handler = fn name, m10s, m6a, nil -> IO.inspect({name, m10s, m6a}, label: "Ecto") end
:telemetry.attach(self(), [:my_app, :repo, :query], handler, nil)
```

To understand why, we need to look a little into how `iex` works at all.

Your shell is a process, started by `IEx.Server.run/1`. It evaluates the code you type in another
process called an _evaluator_ running code starting with `IEx.Evaluator.init/4`.

Input and output devices are also processes, sending and receiving messages according to the
[Erlang I/O Protocol](https://erlang.org/doc/apps/stdlib/io_protocol.html). The Erlang
documentation for `:erlang.group_leader/0` says:

> Every process is a member of some process group and all groups have a group leader.
> All I/O from the group is channeled to the group leader.

It doesn't say _how_ the I/O from the group is channeled, but it's pretty simple: any function
doing I/O will end up with some lower level function looking up your group leader and using it as
the device if a specific device wasn't given.

Sometimes this is direct: `:io.put_chars/1` calls `:erlang.group_leader/0` and gives it as the
first argument to `:io.put_chars/2`. `:io.request/1` similarly calls `:io.request/2` with the
group leader.

Most of the time, though, it's indirect. I/O from almost everywhere else in OTP arrives at
`:io.request/2` (and, rarely, `:io.requests/2`) with an atom as its first argument. If that atom
is `:standard_io`, it's replaced with the group leader. If not, the device is looked up by name in
the process registry with `:erlang.whereis/1`.

In Elixir, `IO.puts/2` maps its device argument from `:stdio` to Erlang's `:standard_io`,
`:stderr` to `:standard_error`, leaves other device arguments alone, and calls `:io.put_chars/2`
which proceeds as above.

Given the above, these calls do the same thing:

```elixir
:io.put_chars('pretty!\\n')
:io.put_chars(:erlang.group_leader(), 'pretty!\\n')
:io.put_chars(:standard_io, 'pretty!\\n')
IO.puts("pretty!")
IO.puts(:stdio, "pretty!")
IO.puts(:standard_io, "pretty!")
IO.puts(Process.group_leader(), "pretty!")
```

Back to our "missing" output, consider what happens when you send I/O to various device aliases
while your group leader is set to device other than your terminal. Paste this code into the `iex`
prompt:

```elixir
test_output = fn device -> IO.puts(device, ["output to ", Kernel.inspect(device)]) end

run_experiments = fn ->
  {:ok, dev_null} = File.open("/dev/null", [:read, :write])
  group_leader = Process.group_leader()

  try do
    Process.group_leader(self(), dev_null)

    [:stdio, :standard_io, :stderr, :standard_error, :user]
    |> Enum.map(fn device -> {device, test_output.(device)} end)
    |> Enum.into(%{})
  after
    Process.group_leader(self(), group_leader)
    File.close(dev_null)
  end
end

run_experiments |> Task.async() |> Task.await()
```

At the `iex` prompt, you'll see output for `:stderr`, `:standard_error`, and `:user` but not for
`:dev_null`, `stdio`, or `:standard_io` despite the result showing `IO.puts/2` returned `:ok`
every time.

The same is happening when `Ecto.Adapters.SQL` calls `:telemetry.execute/3`:

* Your telemetry handler is run in the same process that ran the query — often, it's
* handling the request end-to-end including Plug and Phoenix and Absinthe

* Your handler's call to `IO.inspect/2` gets the default device `:stdio`

* That default gets resolved to the request's group leader

* Your output ends up in the node's standard output

* At the `iex -S mix phx.server` prompt, your shell is on the same node and you can't see the
  difference, setting up the surprise for when you use a remote shell

To send the telemetry inspection to your remote console, capture your group leader outside the
handler and write to it explicitly from inside the handler:

```elixir
device = Process.group_leader()
handler = fn name, m10s, m6a, nil ->
  IO.inspect(device, {name, m10s, m6a}, label: "Ecto")
end
:telemetry.attach(self(), [:my_app, :repo, :query], handler, nil)
```

You can _almost_ get it down to a one-liner if you lose the label:

```elixir
dev = Process.group_leader()
:telemetry.attach(self(), [:my_app, :repo, :query], &IO.inspect(&4, {&1, &2, &3}, []), dev)
```

### The Case of the Missing Colors

Trying to read pages of data structures without syntax coloring is hard. Where'd the colors go?

Let's check which nodes are running our shell and its evaluator when we run `iex`:

```plain
iex> self() |> :erlang.node()
:nonode@nohost

iex> :erlang.group_leader() |> :erlang.node()
:nonode@nohost
```

… and again when we run `_build/dev/rel/my_app/bin/my_app remote`:

```plain
iex> self() |> :erlang.node()
:"my_app@127.0.0.1"

iex> :erlang.group_leader() |> :erlang.node()
:"rem-b987-my_app@127.0.0.1"
```

If the latter is less colorful than the former, it's because:

* Your remote shell called `IEx.Config.inspect_opts/0` from a process on `:"my_app@127.0.0.1"`,
  not the hidden node running the other end of your shell

* `IEx.Config.color/1` fell through to `IO.ANSI.enabled?/0` because you didn't `config :iex`

* ANSI wasn't enabled because your application node had its output redirected at startup

To put some color into your telemetry inspection, get the inspection options from your hidden
node with `:rpc.call/4`. Extending our example above:

```elixir
device = Process.group_leader()
opts = device |> :erlang.node() |> :rpc.call(IEx.Config, :inspect_opts, [])
opts = Keyword.merge(opts, pretty: true, label: "Ecto")
handler = fn name, m10s, m6a, nil ->
IO.puts(device, [Kernel.inspect({name, m10s, m6a}, opts), IO.ANSI.reset()])
end
:telemetry.attach(self(), [:my_app, :repo, :query], handler, nil)
```

You'll need the `IO.ANSI.reset/0` result to avoid the yellow reset handling numbers and functions
for you also bleeding through to your prompt.

### The Case of the Fixed Width

`IEx.Config.width/0` returns the minimum of:

* Your console's width
* `Application.get_env(:iex, :width, 80)`

To inspect at your console's full width, measure it outside your handler with `io.columns/1`.
Extending our example again:

```elixir
device = Process.group_leader()
opts = device |> :erlang.node() |> :rpc.call(IEx.Config, :inspect_opts, [])
{:ok, width} = :io.columns(device)
opts = Keyword.merge(opts, pretty: true, width: width, label: "Ecto")
handler = fn name, m10s, m6a, nil ->
IO.puts(device, [Kernel.inspect({name, m10s, m6a}, opts), IO.ANSI.reset()])
end
:telemetry.attach(self(), [:my_app, :repo, :query], handler, nil)
```

We've done it! All three problems, solved… until you run them from a console for which
`io.columns/1` returns `{:error, :enotsup}`, or for which ANSI is genuinely not available and the
reset will pollute your output. Go ahead, fix those; I'll wait right here.

(Y'know, you _could_ cheat. Just sayin'.)

### The Case of Great Relief

To get the right colors, width, and output device, use `Pretty.bind/1` to get a
`t:Pretty.inspector/1` function:

```elixir
dump = Pretty.bind(label: "Ecto")
```

Use that function instead of `IO.inspect/1` or `Pretty.inspect/1`. Our `Ecto.Adapters.SQL` example
becomes:

```elixir
dump = Pretty.bind(label: "Ecto")
handler = fn name, m10s, m6a, nil -> dump.({name, m10s, m6a}) end
:telemetry.attach(self(), [:my_app, :repo, :query], handler, nil)
```

<!-- MDOC -->
## Copyright and License

Copyright (c) 2020 Garth Kidd

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
