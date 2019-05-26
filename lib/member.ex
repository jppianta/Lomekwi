defmodule Member do
  @moduledoc """
    Create intances to manage file and artifacts
  """

  require Logger

  @doc """
    Instantiates a new Member exposing just splitFile and mountFile functions
  """
  def new(config) do
    if (config.key == nil) do
      {:error, "Key must be defined"}
    else
      %{
        :splitFile => splitFile(config.key, config.baseDir, config.artifactSize),
        :mountFile => mountFile(config.key, config.baseDir)
      }
    end
  end

  # Returns a function that cryptographs the file and splits the file into artifacts
  defp splitFile(key, baseDir, artifactSize) do
    fn fileName ->
      completeFileName = baseDir <> fileName
      {:ok, file} = File.open(completeFileName, [:binary, :read])
      data = IO.binread(file, :all)
      {:ok, {init_vector, cipher_text}} = ExCrypto.encrypt(key, data)
      size = div(bit_size(cipher_text), 8)
      parts = div(size, artifactSize)
      if parts > 0 do
        Enum.each(0..(parts - 1), fn part ->
          partData = binary_part(cipher_text, part * artifactSize, artifactSize)
          createArtifact(fileName, baseDir, part, partData)
        end)
      end
      rest = rem(size, artifactSize)
      if rest > 0 do
        partData = binary_part(cipher_text, size - rest, rest)
        createArtifact(fileName, baseDir, parts, partData)
      end
      createArtifact(fileName, baseDir, "vector", init_vector)
      File.close(file)
    end
  end

  # Creates an artifact with fileName and content
  defp createArtifact(fileName, baseDir, part, content) do
    newFileName = to_string(part) <> "__" <> fileName <> ".ats"
    completeFileName = baseDir <> newFileName

    case File.open(completeFileName, [:binary, :write]) do
      {:ok, file} ->
        IO.binwrite(file, content)
        Logger.info("Arifact #{completeFileName} created")
        File.close(file)
    end
  end

  # Returns a function that search for the artifacts of a file, mounts them into a file and decryptographs it
  defp mountFile(key, baseDir) do
    fn fileNam ->
      info = findArtifacts(fileNam, baseDir)
      vectorFileName = baseDir <> info.vector.artifactName
      fileNames = Enum.map(info.artifacts, fn art -> baseDir <> art.artifactName end)

      case File.open(baseDir <> fileNam, [:binary, :write]) do
        {:ok, file} ->
          data =
            Enum.reduce(fileNames, <<>>, fn fileName, currData ->
              case File.open(fileName, [:binary, :read]) do
                {:ok, artifact} ->
                  d = IO.binread(artifact, :all)
                  File.close(artifact)
                  Logger.info("Artifact #{fileName} read")
                  currData <> d

                {:error, err} ->
                  Logger.info("#{fileName} #{err}")
                  currData
              end
            end)

          case File.open(vectorFileName, [:binary, :read]) do
            {:ok, vectorFile} ->
              init_vector = IO.binread(vectorFile, :all)

              case ExCrypto.decrypt(key, init_vector, data) do
                {:ok, decData} ->
                  IO.binwrite(file, decData)
              end
          end

          File.close(file)
      end
    end
  end

  # List all artifacts of a fileName on a folder
  defp findArtifacts(fileName, dirPath) do
    {:ok, files} = File.ls(dirPath)

    data =
      Enum.reduce(files, %{:vector => nil, :artifacts => []}, fn file, currData ->
        if not File.dir?(file) and artifact?(file) do
          artifact = getArtifactDetails(file)

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

    %{
      :artifacts =>
        Enum.sort(data.artifacts, &(String.to_integer(&1.slice) <= String.to_integer(&2.slice))),
      :vector => data.vector
    }
  end

  # Verifies if file is an artifact
  defp artifact?(file) do
    String.ends_with?(file, ".ats")
  end

  # Get slice, fileName and artifactName of an artifact
  defp getArtifactDetails(art) do
    pattern = :binary.compile_pattern(["__", ".ats"])
    [slice | fileName] = String.split(art, pattern)

    %{
      :slice => slice,
      :fileName => List.to_string(fileName),
      :artifactName => art
    }
  end
end
