defmodule Lomekwi do
  def init do
    generateKey()
  end

  def splitFile(fileName) do
    case File.stat(fileName) do
      {:ok, %{size: size}} ->
        {:ok, file} = File.open(fileName, [:binary, :read])
        half = div(size, 2)
        rest = rem(size, 2)
        data1 = IO.binread(file, half)
        data2 = IO.binread(file, half + rest)
        createArtifact(fileName, 0, data1)
        createArtifact(fileName, 1, data2)
        File.close(file)
    end
  end

  def createArtifact(fileName, part, content) do
    newFileName = to_string(part) <> "__" <> fileName <> ".ats"

    case File.open(newFileName, [:binary, :write]) do
      {:ok, file} ->
        IO.binwrite(file, content)
        File.close(file)
    end
  end

  def mountFileFromArtifacts(fileNames) do
    newFileName = "newFile.txt"

    case File.open(newFileName, [:binary, :write]) do
      {:ok, file} ->
        Enum.each(fileNames, fn fileName ->
          case File.open(fileName, [:binary, :read]) do
            {:ok, artifact} ->
              artifactData = IO.binread(artifact, :all)
              IO.binwrite(file, artifactData)
              File.close(artifact)
              IO.puts("Artifact #{fileName} read")
          end
        end)

        File.close(file)
    end
  end

  defp generateKey do
    case File.stat("key.bin") do
      {:ok, stat} ->
        case File.open("key.bin", [:binary, :read]) do
          {:ok, file} ->
            key = IO.binread(file, :all)
            File.close(file)
            key
        end
      {:error, err} ->  
        case File.open("key.bin", [:binary, :write]) do
          {:ok, file} ->
            case ExCrypto.generate_aes_key(:aes_256, :bytes) do
              { :ok, key } ->
                IO.binwrite(file, key)
                File.close(file)
                key
            end
        end
    end
  end
end
