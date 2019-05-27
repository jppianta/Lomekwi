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
        :splitFile => splitFile(config.key, config.artifactSize),
        :findArtifacts => findArtifacts(config.baseDir),
        :baseDir => config.baseDir
      }
    end
  end

  # Returns a function that cryptographs the file and splits the file into artifacts
  defp splitFile(key, artifactSize) do
    fn fileName, baseDir ->
      filePath = baseDir <> fileName
      {:ok, file} = File.open(filePath, [:binary, :read])
      data = IO.binread(file, :all)
      File.close(file)
      {:ok, {init_vector, cipher_text}} = ExCrypto.encrypt(key, data)
      size = div(bit_size(cipher_text), 8)
      parts = div(size, artifactSize)
      rest = rem(size, artifactSize)

      artifacts =
        splitParts(parts, cipher_text, artifactSize, fileName) ++
          splitRest(rest, cipher_text, fileName, size, parts)

      artifacts ++ [%{:fileName => fileName, :content => init_vector, :part => "vector"}]
    end
  end

  defp splitParts(parts, content, artifactSize, fileName) do
    if parts > 0 do
      Enum.map(0..(parts - 1), fn part ->
        partData = binary_part(content, part * artifactSize, artifactSize)
        %{:fileName => fileName, :content => partData, :part => to_string(part)}
      end)
    else
      []
    end
  end

  defp splitRest(rest, content, fileName, size, part) do
    if rest > 0 do
      partData = binary_part(content, size - rest, rest)
      [%{:fileName => fileName, :content => partData, :part => to_string(part)}]
    else
      []
    end
  end

  # List all artifacts of a fileName on a folder
  defp findArtifacts(baseDir) do
    fn fileName ->
      {:ok, files} = File.ls(baseDir)

      Enum.reduce(files, %{:vector => nil, :artifacts => []}, fn file, currData ->
        if not File.dir?(file) and artifact?(file) do
          Logger.info("Artifact Found: #{file}")
          artifact = getArtifactDetails(file, baseDir)

          if artifact.fileName == fileName do
            if artifact.slice === "vector" do
              %{
                :vector => artifact,
                :artifacts => currData.artifacts
              }
            else
              %{
                :vector => currData.vector,
                :artifacts => currData.artifacts ++ [artifact]
              }
            end
          else
            currData
          end
        else
          currData
        end
      end)
    end
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
end
