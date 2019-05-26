defmodule Lomekwi do
  @moduledoc """
    Manages Key and Member constructions
  """

  @doc """
    Instantiates a new Member using the baseDir and the existing/generated key
  """
  def init(config) do
    conf = Map.merge(LomekwiConfig.config(), config)
    conf = Map.merge(conf, %{:key => generateKey(conf.baseDir)})
    Member.new(conf)
  end

  # Uses the baseDir to verify if a file with a key already exists. If not, creates one and stores it into a file
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
