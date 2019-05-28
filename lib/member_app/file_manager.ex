defmodule FileManager do
  @moduledoc """
    Manages Key and Member constructions
  """

  use Agent
  require Logger

  def init do
    start_link(%{})
  end

  defp start_link(_opts) do
    Agent.start_link(fn -> %{:system_key => nil, :members => %{}} end, name: __MODULE__)
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
    IO.puts("exit")
    {:noreply, state}
  end

  @doc """
    Gets a value from the `bucket` by `key` and splits the member file
  """
  def splitFile(key, fileName, fileDir) do
    member = Agent.get(__MODULE__, &Map.get(&1.members, key))

    Enum.each(member.splitFile.(fileName, fileDir), fn artifact ->
      createArtifact(artifact)
    end)
  end

  def testSplit(key) do
    splitFile(key, "inputFile.txt", "./test/mock_components/")
  end

  defp findArtifacts(fileName) do
    arts =
      getMembers()
      |> Enum.reduce(%{:vector => nil, :artifacts => []}, fn member, currData ->
        artifacts = member.findArtifacts.(fileName)

        if artifacts.vector != nil do
          %{
            :vector => artifacts.vector,
            :artifacts => currData.artifacts ++ artifacts.artifacts
          }
        else
          %{
            :vector => currData.vector,
            :artifacts => currData.artifacts ++ artifacts.artifacts
          }
        end
      end)

    %{
      :vector => arts.vector,
      :artifacts =>
        Enum.sort(arts.artifacts, &(String.to_integer(&1.slice) < String.to_integer(&2.slice)))
    }
  end

  def mountFile(fileName, newFilePath) do
    case File.open(newFilePath, [:binary, :write]) do
      {:ok, file} ->
        artifacts = findArtifacts(fileName)

        data =
          Enum.reduce(artifacts.artifacts, <<>>, fn artifact, currData ->
            currData <> artifact.content
          end)

        case ExCrypto.decrypt(getSystemKey(), artifacts.vector.content, data) do
          {:ok, decData} ->
            IO.binwrite(file, decData)
        end

        File.close(file)
        Logger.info("File Created: #{newFilePath}")
    end
  end

  @doc """
    Instantiates a new Member using the baseDir and the existing/generated key
  """
  def new_member(key, config) do
    systemKey = getSystemKey()

    if systemKey == nil do
      newKey = generateKey()
      Agent.update(__MODULE__, &Map.put(&1, :system_key, newKey))
    end

    conf = Map.merge(LomekwiConfig.config(), config)
    conf = Map.merge(conf, %{:key => getSystemKey()})
    Logger.info("Member Added: #{key}")
    createDir(conf.baseDir)

    Agent.update(__MODULE__, fn state ->
      %{
        :system_key => state.system_key,
        :members => Map.put(state.members, key, Member.new(conf))
      }
    end)
  end

  defp createDir(dir) do
    if not File.exists?(dir) do
      File.mkdir_p(dir)
    end
  end

  defp generateKey do
    case ExCrypto.generate_aes_key(:aes_256, :bytes) do
      {:ok, key} ->
        key
    end
  end

  # Creates an artifact with fileName and content
  defp createArtifact(artifact) do
    getRandomMember().save_artifact.(artifact)
    # newFileName = artifact.part <> "__" <> artifact.fileName <> ".ats"
    # completeFileName = getRandomMember().baseDir <> newFileName

    # case File.open(completeFileName, [:binary, :write]) do
    #   {:ok, file} ->
    #     IO.binwrite(file, artifact.content)
    #     Logger.info("Arifact Created: #{completeFileName}")
    #     File.close(file)
    # end
  end

  defp getSystemKey do
    Agent.get(__MODULE__, & &1.system_key)
  end

  def getMembers do
    Agent.get(__MODULE__, & &1.members) |> Map.values()
  end

  defp getRandomMember do
    getMembers() |> Enum.random()
  end
end
