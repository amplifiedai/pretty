defmodule Pretty do
  @moduledoc """
  Inspect values with syntax colors despite your remote console.

  This module addresses two surprises you'll encounter trying to dump data to the remote console
  like you did during development with `iex -S mix`:

  * `IO.inspect/1` _et al_ work fine at the `iex>` prompt but their output goes to the server's
    logs, not your console when you call them from inside a `:telemetry` handler function or other
    troubleshooting mechanism

  * The syntax colors aren't working

  * The inspection width is 80&hellip; just like `iex`, now that you think of it

  Why? See the [explanation](EXPLAIN.html).

  In case of emergency, [BREAK GLASS](explain.html#break-glass) to get what you need with some
  copying and pasting.

  ## Usage

  To get the right syntax colors and inspection width, replace your calls to `IO.inspect/1` with
  calls to `Pretty.inspect/1`:

      Pretty.inspect(<<0, 1, 2>>, width: 40)

  ... and the same for `IO.inspect/2`:

      [1, 2, 3]
      |> IO.inspect(label: "before")
      |> Enum.map(&(&1 * 2))
      |> IO.inspect(label: "after")
      |> Enum.sum()

  To get the right colors, width, and output device, use `Pretty.bind/1` to get an `t:inspector/1`
  function, and use it instead of `IO.inspect/1` or `Pretty.inspect/1`:

      dump = Pretty.bind(label: "Ecto")
      handler = fn name, m10s, m6a, nil -> dump.({name, m10s, m6a}) end
      :telemetry.attach(self(), [:my_app, :repo, :query], handler, nil)
  """

  @typedoc "Keyword options supported by `IO.inspect/2`."
  @type inspect_opts() :: keyword()

  @typedoc """
  A 1-ary inspection function returning its argument unchanged e.g. `IO.inspect/1`.
  """
  @type inspector(item) :: (item -> item)

  @doc """
  Inspect an item, writing the report to the standard output. Return the item unchanged.

  Like `IO.inspect/2`, but with pretty defaults appropriate to the device.

  See `inspect/3` for details on option handling.
  """
  @spec inspect(item, inspect_opts()) :: item when item: var
  def inspect(item, opts \\ []) when is_list(opts) do
    inspect(:stdio, item, opts)
  end

  @doc """
  Inspect an item, writing the report to a device. Return the item unchanged.

  Like `IO.inspect/3`, but with pretty defaults appropriate to the `device`:

  * Set `pretty` to `true`
  * Set `width` according to the device's `:io.columns/1` if possible, else the `Inspect.Opts`
    default of #{%Inspect.Opts{}.width}
  * Set `syntax_colors` according to the device node's `IEx.Config.inspect_opts/1`
  """
  @spec inspect(IO.device(), item, inspect_opts()) :: item when item: var
  def inspect(device, item, opts) when (is_pid(device) or is_atom(device)) and is_list(opts) do
    device = resolve_device(device)
    opts = pretty_inspect_opts(device, opts)
    inspect_put_and_reset(device, item, opts)
  end

  @doc """
  Bind an inspection function to the current standard output.

  See `bind/2` for more details.
  """
  @spec bind(inspect_opts()) :: inspector(any())
  def bind(opts \\ []) when is_list(opts) do
    bind(:stdio, opts)
  end

  @doc """
  Bind an inspection function to a particular device.

  The inspector's device and options are resolved when `bind/2` is called, not when the inspector
  is called. If you bind at the remote console prompt, the device and options will remain
  appropriate for your console no matter which process calls the inspector.

  See `inspect/3` for details on option handling.
  """
  @spec bind(IO.device(), inspect_opts()) :: inspector(any())
  def bind(device, opts) when (is_pid(device) or is_atom(device)) and is_list(opts) do
    device = resolve_device(device)
    opts = pretty_inspect_opts(device, opts)
    fn item -> inspect_put_and_reset(device, item, opts) end
  end

  @spec inspect_put_and_reset(pid(), item, inspect_opts()) :: item when item: var
  defp inspect_put_and_reset(device_pid, item, opts) when is_pid(device_pid) and is_list(opts) do
    label = get_label(opts)
    report = Kernel.inspect(item, opts)
    reset = get_ansi_reset(opts)
    IO.puts(device_pid, [label, report, reset])
    item
  end

  @doc false
  @spec get_label(inspect_opts()) :: iodata()
  def get_label(opts) do
    case Keyword.get(opts, :label) do
      nil -> []
      label -> [label, ": "]
    end
  end

  @doc false
  @spec get_ansi_reset(inspect_opts()) :: iodata()
  def get_ansi_reset(opts) do
    case Keyword.get(opts, :syntax_colors, []) do
      # prevent default yellow "reset" bleeding through
      # reset normally supplied by IO.ANSI.format/2 in IEx.color/2
      [_ | _] -> IO.ANSI.reset()
      _ -> []
    end
  end

  @spec pretty_inspect_opts(device_pid :: pid(), opts :: inspect_opts()) :: inspect_opts()
  defp pretty_inspect_opts(device_pid, opts) when is_pid(device_pid) and is_list(opts) do
    width = width(device_pid)

    device_pid
    |> get_node_inspect_opts()
    |> Keyword.put(:pretty, true)
    |> Keyword.put(:width, width)
    |> Keyword.merge(opts)
  end

  @spec get_node_inspect_opts(device_pid :: pid()) :: keyword()
  defp get_node_inspect_opts(device_pid) when is_pid(device_pid) do
    device_pid
    |> :erlang.node()
    |> :rpc.call(IEx.Config, :inspect_opts, [])
  end

  @doc false
  @spec width(device :: IO.device()) :: integer()
  def width(device) when is_pid(device) or is_atom(device) do
    case :io.columns(device) do
      {:error, :enotsup} -> %Inspect.Opts{}.width
      {:ok, width} -> width
    end
  end

  @doc false
  @spec resolve_device(IO.device()) :: IO.device()
  def resolve_device(pid) when is_pid(pid), do: pid
  def resolve_device(:stderr), do: :erlang.whereis(:standard_error)
  def resolve_device(:stdio), do: resolve_device(:standard_io)
  def resolve_device(:standard_io), do: :erlang.group_leader()
  def resolve_device(name) when is_atom(name), do: :erlang.whereis(name)
end
