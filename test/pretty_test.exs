defmodule PrettyTest do
  use ExUnit.Case, async: false

  defp expect(device, request, reply) when is_pid(device) do
    TestDevice.expect(device, request, reply)
  end

  def open_test_device do
    {:ok, device} = TestDevice.open()

    assert is_pid(device), "did not get pid for device"
    on_exit(make_ref(), fn -> :ok = File.close(device) end)

    device
  end

  def check!(device) when is_pid(device) do
    {:ok, unsatisfied} = TestDevice.flush(device)
    assert unsatisfied == [], "some expected requests weren't made"
  end

  @doc """
  Run a function while controlling its I/O environment:

  * `fun`: the 0-ary function to run
  * `group_leader`: control the result of `Process.group_leader/0`
  * `ansi_enabled`: control the result of `IO.ANSI.enabled?/0`
  """
  def controlled(fun, opts \\ [])
      when is_function(fun, 0) and is_list(opts) do
    {new_group_leader, opts} = Keyword.pop(opts, :group_leader, Process.group_leader())
    {new_ansi_enabled, opts} = Keyword.pop(opts, :ansi_enabled, IO.ANSI.enabled?())
    assert opts == [], "unexpected options"

    group_leader = Process.group_leader()
    ansi_enabled = Application.get_env(:elixir, :ansi_enabled, false)

    try do
      Application.put_env(:elixir, :ansi_enabled, new_ansi_enabled)
      Process.group_leader(self(), new_group_leader)
      assert Process.group_leader() == new_group_leader, "control failed: group_leader"
      assert IO.ANSI.enabled?() == new_ansi_enabled, "control failed: ansi_enabled"
      fun.()
    after
      Process.group_leader(self(), group_leader)
      Application.put_env(:elixir, :ansi_enabled, ansi_enabled)
    end
  end

  describe "get_ansi_reset/1 (internal)" do
    test "no :syntax_colors" do
      assert [] = Pretty.get_ansi_reset([])
    end

    test "empty :syntax_colors" do
      assert [] = Pretty.get_ansi_reset(syntax_colors: [])
    end

    test "non-empty :syntax_colors" do
      reset = IO.ANSI.reset()
      assert ^reset = Pretty.get_ansi_reset(syntax_colors: [reset: :yellow])
    end
  end

  describe "bind/0" do
    test "end-to-end" do
      # :io.columns/1 is called once because we wanted to know
      # :io.columns/1 is called again because `IEx.Config.inspect_opts/0` wanted to know
      device =
        open_test_device()
        |> expect({:get_geometry, :columns}, {:error, :enotsup})
        |> expect({:get_geometry, :columns}, {:error, :enotsup})
        |> expect({:put_chars, :unicode, "1\n"}, :ok)

      inspector =
        controlled(
          fn -> Pretty.bind() end,
          group_leader: device,
          ansi_enabled: false
        )

      assert is_function(inspector, 1)
      assert inspector.(1) == 1
      check!(device)
    end
  end

  describe "bind/1" do
    test "end-to-end" do
      device =
        open_test_device()
        |> expect({:get_geometry, :columns}, {:error, :enotsup})
        |> expect({:get_geometry, :columns}, {:error, :enotsup})
        |> expect({:put_chars, :unicode, "n: 1\n"}, :ok)

      inspector =
        controlled(
          fn -> Pretty.bind(label: "n") end,
          group_leader: device,
          ansi_enabled: false
        )

      assert is_function(inspector, 1)
      assert inspector.(1) == 1
      check!(device)
    end
  end

  describe "bind/2" do
    test "end-to-end with :stdio and label" do
      argument = %Inspect.Opts{}
      expected_output = "label: " <> Kernel.inspect(argument, pretty: true, width: 80) <> "\n"

      device =
        open_test_device()
        |> expect({:get_geometry, :columns}, {:error, :enotsup})
        |> expect({:get_geometry, :columns}, {:error, :enotsup})
        |> expect({:put_chars, :unicode, expected_output}, :ok)

      inspector =
        controlled(
          fn -> Pretty.bind(:stdio, label: "label") end,
          group_leader: device,
          ansi_enabled: false
        )

      assert is_function(inspector, 1)
      assert inspector.(argument) == argument
      check!(device)
    end
  end

  describe "inspect/1" do
    test "end-to-end" do
      device =
        open_test_device()
        |> expect({:get_geometry, :columns}, {:error, :enotsup})
        |> expect({:get_geometry, :columns}, {:error, :enotsup})
        |> expect({:put_chars, :unicode, "n: 1\n"}, :ok)

      assert 1 =
               controlled(
                 fn -> Pretty.inspect(1, label: "n") end,
                 group_leader: device,
                 ansi_enabled: false
               )

      check!(device)
    end
  end

  describe "resolve_device/1 (internal)" do
    test "pid" do
      device = open_test_device()
      assert ^device = Pretty.resolve_device(device)
    end

    test "named device" do
      device = open_test_device()
      Process.register(device, __MODULE__)
      assert ^device = Pretty.resolve_device(__MODULE__)
    end

    test ":standard_error" do
      pid = Process.whereis(:standard_error)
      assert ^pid = Pretty.resolve_device(:standard_error)
    end

    test ":standard_io" do
      pid = Process.group_leader()
      assert ^pid = Pretty.resolve_device(:standard_io)
    end

    test ":stderr" do
      pid = Process.whereis(:standard_error)
      assert ^pid = Pretty.resolve_device(:stderr)
    end

    test ":stdio" do
      pid = Process.group_leader()
      assert ^pid = Pretty.resolve_device(:stdio)
    end
  end

  describe "width/1 (internal)" do
    test "device without columns" do
      device = open_test_device() |> expect({:get_geometry, :columns}, {:error, :enotsup})
      default_width = %Inspect.Opts{}.width
      assert ^default_width = Pretty.width(device)
      check!(device)
    end

    test "device with columns" do
      device = open_test_device() |> expect({:get_geometry, :columns}, 98)
      assert 98 = Pretty.width(device)
      check!(device)
    end
  end
end
