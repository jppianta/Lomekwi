defmodule FileManager do
  @moduledoc """
    Manages Key and Member constructions
  """

  use Agent
  require Logger

  def new_system(config) do
    key = generateKey()
    File.write(config.base_dir <> "key.bin", key, [:binary])
    start_link(key, config.base_dir)
  end

  # def join_system(config, system_member_ip) do
    
  # end

  defp start_link(key, base_dir) do
    self_ip = get_self_ip()
    Agent.start_link(fn -> %{:ip => self_ip, :base_dir => base_dir, :system_key => key, :members => %{}} end, name: __MODULE__)
  end

  defp get_self_ip do
    {:ok, ifs} = :inet.getif()
    Enum.at(ifs, 0) |> elem(0) |> Tuple.to_list() |> Enum.join(".")
  end

  def save_artifact(artifact) do
    path = get_base_dir() <> to_string(artifact.slice) <> "__" <> artifact.fileName <> ".ats"
    File.write(path, artifact.content)
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
    conf = Map.merge(LomekwiConfig.config(), config)
    conf = Map.merge(conf, %{:key => getSystemKey()})
    Logger.info("Member Added: #{key}")
    createDir(conf.baseDir)

    Agent.update(__MODULE__, fn state ->
      %{
        :ip => state.ip,
        :base_dir => state.base_dir,
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

  def getSystemKey do
    Agent.get(__MODULE__, & &1.system_key)
  end

  def get_base_dir do
    Agent.get(__MODULE__, & &1.base_dir)
  end

  def get_IP do
    Agent.get(__MODULE__, & &1.ip)
  end

  def getMembers do
    Agent.get(__MODULE__, & &1.members) |> Map.values()
  end

  defp getRandomMember do
    getMembers() |> Enum.random()
  end
end
