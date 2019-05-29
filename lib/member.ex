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

      case HTTPoison.post(addrs <> ":8085/save_artifact", message) do
        {:ok, _conn} ->
          :ok

        {:error, _conn} ->
          :error
      end
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
      case HTTPoison.post(
             addrs <> ":8085/find_artifact",
             Jason.encode!(%{:fileName => fileName, :send_to => send_to})
           ) do
        {:ok, _conn} ->
          :ok

        {:error, _conn} ->
          :error
      end
    end

    # {:ok, files} = File.ls(baseDir)

    # Enum.reduce(files, %{:vector => nil, :artifacts => []}, fn file, currData ->
    #   if not File.dir?(file) and artifact?(file) do
    #     Logger.info("Artifact Found: #{file}")
    #     artifact = getArtifactDetails(file, baseDir)

    #     if artifact.fileName == fileName do
    #       if artifact.slice === "vector" do
    #         %{
    #           :vector => artifact,
    #           :artifacts => currData.artifacts
    #         }
    #       else
    #         %{
    #           :vector => currData.vector,
    #           :artifacts => currData.artifacts ++ [artifact]
    #         }
    #       end
    #     else
    #       currData
    #     end
    #   else
    #     currData
    #   end
    # end)
  end
end
