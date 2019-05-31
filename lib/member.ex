defmodule Member do
  @moduledoc """
    Create intances to manage file and artifacts
  """

  require Logger

  @doc """
    Instantiates a new Member exposing just splitFile and mountFile functions
  """
  def new(config) do
    if config.key == nil do
      {:error, "Key must be defined"}
    else
      %{
        :findArtifacts => findArtifacts(config.addrs),
        :save_artifact => save_artifact(config.addrs),
        :base_dir => config.base_dir,
        :addrs => config.addrs
      }
    end
  end

  defp save_artifact(addrs) do
    fn artifact ->
      message =
        encondeName(artifact.fileName, 32) <> encondeName(artifact.part, 16) <> artifact.content

      send_package(addrs <> ":8085/save_artifact", message)
    end
  end

  defp encondeName(name, size) do
    content = to_charlist(name)

    Enum.reduce(0..(size - 1), <<>>, fn idx, acc ->
      char = Enum.at(content, idx)

      if char == nil do
        acc <> <<0>>
      else
        acc <> <<char>>
      end
    end)
  end

  # List all artifacts of a fileName on a folder
  defp findArtifacts(addrs) do
    fn fileName, send_to ->
      send_package(
        addrs <> ":8085/find_artifact",
        Jason.encode!(%{:fileName => fileName, :send_to => send_to})
      )
    end
  end

  defp send_package(destination, content) do
    case HTTPoison.post(destination, content) do
      {:ok, _conn} ->
        :ok

      {:error, error} ->
        Logger.error("Package Error: #{error.reason}")
        send_package(destination, content)
    end
  end
end
