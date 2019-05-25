require Member

defmodule Lomekwi do
  def init(baseDir) do
    Member.new(generateKey(baseDir), baseDir)
  end

  defp generateKey(baseDir) do
    keyFileName = baseDir <> "key.bin"

    case File.open(keyFileName, [:binary, :read]) do
      {:ok, file} ->
        key = IO.binread(file, :all)
        File.close(file)
        key

      {:error, err} ->
        IO.puts(err)

        case File.open(keyFileName, [:binary, :write]) do
          {:ok, file} ->
            case ExCrypto.generate_aes_key(:aes_256, :bytes) do
              {:ok, key} ->
                IO.binwrite(file, key)
                File.close(file)
                key
            end
        end
    end
  end
end
