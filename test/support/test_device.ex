defmodule TestDevice do
  @moduledoc false

  defmodule State do
    @moduledoc false

    @enforce_keys [:q]
    defstruct [:q]

    @type expected_request :: any()
    @type intended_reply :: any()
    @type expectation :: {expected_request(), intended_reply()}

    @type t :: %__MODULE__{
            q: :queue.queue(expectation())
          }

    def new do
      %__MODULE__{q: :queue.new()}
    end

    def flush(%__MODULE__{} = state) do
      %{state | q: :queue.new()}
    end

    def expect(%__MODULE__{q: q} = state, {request, reply}) do
      q = :queue.in({request, reply}, q)
      %{state | q: q}
    end

    def pop_next_expectation(%__MODULE__{q: q} = state) do
      {{:value, {request, reply}}, q} = :queue.out(q)
      state = %{state | q: q}
      {{request, reply}, state}
    end

    def list_remaining_expectations(%__MODULE__{q: q}) do
      :queue.to_list(q)
    end
  end

  @callback handle_io_request(any()) :: any()

  @doc "Open the device."
  @spec open() :: {:ok, pid()}
  def open do
    state = State.new()
    Task.start_link(fn -> loop(state) end)
  end

  @doc "Expect a request and queue up a reply."
  def expect(device, request, reply) when is_pid(device) do
    :ok = mock_request(device, {:expect, request, reply})
    device
  end

  @doc "Flush expectations and return trailing requests."
  def flush(device) when is_pid(device), do: mock_request(device, :flush)

  defp mock_request(device, request) when is_pid(device) do
    ref = :erlang.monitor(:process, device)
    Process.send(device, {:mock_request, self(), ref, request}, [])

    receive do
      {:mock_reply, ^ref, reply} ->
        :erlang.demonitor(ref, [:flush])
        reply

      {'DOWN', ^ref, _, _, _} ->
        {:error, :terminated}
    after
      1000 ->
        :erlang.demonitor(ref, [:flush])
        {:error, :timeout}
    end
  end

  @spec loop(State.t()) :: any()
  defp loop(%State{} = state) do
    receive do
      {:file_request, pid, ref, :close} ->
        Process.send(pid, {:io_reply, ref, :ok}, [])

      {:mock_request, pid, ref, {:expect, request, reply}} ->
        Process.send(pid, {:mock_reply, ref, :ok}, [])
        state |> State.expect({request, reply}) |> loop()

      {:mock_request, pid, ref, :flush} ->
        unsatisfied = State.list_remaining_expectations(state)
        Process.send(pid, {:mock_reply, ref, {:ok, unsatisfied}}, [])
        state |> State.flush() |> loop()

      {:io_request, pid, ref, request} ->
        {{expected, reply}, state} = State.pop_next_expectation(state)

        reply =
          case request do
            ^expected ->
              reply

            unexpected ->
              {:current_stacktrace, stacktrace} = Process.info(pid, :current_stacktrace)
              repr_stacktrace = Exception.format_stacktrace(stacktrace)

              repr_request = inspect(unexpected)

              repr_reply = inspect(:io.request(:standard_io, request))

              puts_ansi([
                :red,
                "did not expect: ",
                :yellow,
                repr_request,
                :reset,
                " from:\n",
                repr_stacktrace,
                :yellow,
                "stdio replied: ",
                "expect_request(#{repr_request}, #{repr_reply})"
              ])

              {:error, {:request, request}}
          end

        Process.send(pid, {:io_reply, ref, reply}, [])
        loop(state)

      unexpected_event ->
        puts_ansi([:red, "unexpected event: ", :reset, inspect(unexpected_event)])
        loop(state)
    end
  end

  defp puts_ansi(chardata) when is_list(chardata) do
    IO.puts(:stderr, IO.ANSI.format(chardata))
  end
end
