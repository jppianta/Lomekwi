defmodule Lomekwi.FileManager do
  @moduledoc """
    Manages Key and Member constructions
  """

  use Agent
  require Logger

  # Client
  def start_link(config) do
    Agent.start_link(fn -> config end, name: __MODULE__)
  end

  # Server
  def save_artifact(artifact) do
    path = get_base_dir() <> to_string(artifact.slice) <> "__" <> artifact.fileName <> ".ats"
    File.write(path, artifact.content)
  end

  # Server
  def findArtifacts(fileName, send_to) do
    {:ok, files} = File.ls(get_base_dir())

    Enum.each(files, fn file ->
      if not File.dir?(file) and artifact?(file) do
        artifact = getArtifactDetails(file, get_base_dir())

        if artifact.fileName == fileName and artifact.slice != "meta" do
          message =
            encondeName(artifact.fileName, 32) <>
              encondeName(artifact.slice, 16) <> artifact.content

          send_package(send_to <> ":8085/receive_artifact", message, "Receive Artifact")
        end
      end
    end)
  end

  defp send_package(destination, content, type \\ "") do
    case HTTPoison.post(destination, content) do
      {:ok, _conn} ->
        :ok

      {:error, error} ->
        Logger.error("Package Error: #{type}, #{error.reason}")
        send_package(destination, content)
    end
  end

  # Server
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

  # Verifies if file is an artifact
  # Server
  defp artifact?(file) do
    String.ends_with?(file, ".ats")
  end

  # Get slice, fileName and artifactName of an artifact
  # Server
  defp getArtifactDetails(art, baseDir) do
    pattern = :binary.compile_pattern(["__", ".ats"])
    [slice | fileName] = String.split(art, pattern)

    case File.open(baseDir <> art, [:binary, :read]) do
      {:ok, artifact} ->
        data = IO.binread(artifact, :all)
        File.close(artifact)

        %{
          :slice => slice,
          :fileName => List.to_string(fileName),
          :artifactName => art,
          :content => data
        }
    end
  end

  # Both
  defp get_base_dir do
    Agent.get(__MODULE__, & &1.base_dir)
  end
end
