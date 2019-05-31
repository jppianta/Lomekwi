defmodule Lomekwi.FileManager do
  @moduledoc """
    Manages Key and Member constructions
  """

  use Agent
  require Logger

  def start_link(config) do
    Agent.start_link(fn -> config end, name: __MODULE__)
  end

  def save_artifact(artifact) do
    path = get_base_dir() <> to_string(artifact.slice) <> "__" <> artifact.fileName <> ".ats"
    File.write(path, artifact.content)
  end

  def findArtifacts(fileName, send_to) do
    {:ok, files} = File.ls(get_base_dir())

    Enum.each(files, fn file ->
      if not File.dir?(file) and artifact?(file) do
        artifact = getArtifactDetails(file, get_base_dir())

        if artifact.fileName == fileName and artifact.slice != "meta" do
          # Logger.info("Artifact Found: #{file}")

          message =
            encondeName(artifact.fileName, 32) <>
              encondeName(artifact.slice, 16) <> artifact.content

          case HTTPoison.post(send_to <> ":8085/receive_artifact", message) do
            {:ok, _conn} ->
              # Logger.info("Artifact Sent: #{file}")
              :ok

            {:error, _conn} ->
              :error
          end
        end
      end
    end)
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

  # Verifies if file is an artifact
  defp artifact?(file) do
    String.ends_with?(file, ".ats")
  end

  # Get slice, fileName and artifactName of an artifact
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

  def get_base_dir do
    Agent.get(__MODULE__, & &1.base_dir)
  end

  def get_IP do
    Agent.get(__MODULE__, & &1.ip)
  end
end
