defmodule LogDNA.Backend do
  @behaviour :gen_event
  import LogDNA.Config
  alias LogDNA.{Formatter, Ingestion}

  defstruct level: :debug, metadata: []

  def init(__MODULE__) do
    HTTPoison.start()
    {:ok, initial_state()}
  end

  # Not buffering anything, no-op
  def handle_event(:flush, state), do: {:ok, state}
  def handle_event({_, gl, {_, _, _, _}}, state) when node(gl) != node(), do: {:ok, state}

  def handle_event(
        {level, _group_leader, {Logger, msg, timestamp, metadata}},
        state
      ) do
    if Logger.compare_levels(state.level, level) != :gt do
      metadata = whitelist_metadata(metadata, state)
      message = message(msg)

      Formatter.format_event(level, message, timestamp, metadata)
      |> Ingestion.prepare_request()
      |> Ingestion.post_request()
    end

    {:ok, state}
  end

  defp message(msg) when is_binary(msg), do: msg
  defp message(msg), do: inspect(msg)

  def handle_call(_request, state) do
    # TODO: Handle config calls
    {:ok, :ok, state}
  end

  defp initial_state() do
    %__MODULE__{
      metadata: logger_config(:metadata, [])
    }
  end

  defp whitelist_metadata(metadata, state) do
    metadata
    |> Keyword.take(state.metadata)
  end
end