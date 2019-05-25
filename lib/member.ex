defmodule Member do
  def new(key, baseDir) do
    %{
      :splitFile => splitFile(key, baseDir),
      :mountFile => mountFile(key, baseDir)
    }
  end

  defp splitFile(key, baseDir) do
    fn fileName ->
      completeFileName = baseDir <> fileName
      {:ok, file} = File.open(completeFileName, [:binary, :read])
      data = IO.binread(file, :all)
      {:ok, {init_vector, cipher_text}} = ExCrypto.encrypt(key, data)
      size = div(bit_size(cipher_text), 8)
      half = div(size, 2)
      rest = rem(size, 2)
      data1 = binary_part(cipher_text, 0, half)
      data2 = binary_part(cipher_text, half, half + rest)
      createArtifact(fileName, baseDir, 0, data1)
      createArtifact(fileName, baseDir, 1, data2)
      createArtifact(fileName, baseDir, "vector", init_vector)
      File.close(file)
    end
  end

  defp createArtifact(fileName, baseDir, part, content) do
    newFileName = to_string(part) <> "__" <> fileName <> ".ats"
    completeFileName = baseDir <> newFileName

    case File.open(completeFileName, [:binary, :write]) do
      {:ok, file} ->
        IO.binwrite(file, content)
        IO.puts("Arifact #{newFileName} created")
        File.close(file)
    end
  end

  defp mountFile(key, baseDir) do
    fn fileNam ->
      info = findArtifacts(fileNam, baseDir)
      vectorFileName = info.vector.artifactName
      fileNames = Enum.map(info.artifacts, fn art -> art.artifactName end)

      case File.open(fileNam, [:binary, :write]) do
        {:ok, file} ->
          data =
            Enum.reduce(fileNames, <<>>, fn fileName, currData ->
              case File.open(fileName, [:binary, :read]) do
                {:ok, artifact} ->
                  d = IO.binread(artifact, :all)
                  File.close(artifact)
                  IO.puts("Artifact #{fileName} read")
                  currData <> d
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

  defp artifact?(file) do
    String.ends_with?(file, ".ats")
  end

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
