defmodule FileManager do
  @moduledoc """
    Manages Key and Member constructions
  """

  use Agent
  require Logger

  def new_system(config) do
    key = generateKey()
    save_key(key, config.base_dir)
    start_link(key, config)
  end

  def join_system(config, system_member_ip) do
    self_ip = get_self_ip()
    data = %{:addrs => self_ip, :base_dir => config.base_dir}
    {:ok, req} = HTTPoison.post(system_member_ip <> ":8085/join_system", Jason.encode!(data))
    items = Binary.split(req.body, 0, global: true)
    system_key = Enum.at(items, 0)
    save_key(system_key, config.base_dir)
    artifact_size = Enum.at(items, 1) |> to_string() |> String.to_integer()

    members =
      Enum.slice(items, 2..-1)
      |> Enum.chunk_every(3)
      |> Enum.reduce(%{}, fn chunk, acc ->
        Map.merge(acc, %{
          Enum.at(chunk, 0) =>
            Member.new(%{
              :key => system_key,
              :artifact_size => artifact_size,
              :base_dir => Enum.at(chunk, 1),
              :addrs => Enum.at(chunk, 2)
            })
        })
      end)

    start_link(system_key, %{:ip => self_ip, :base_dir => config.base_dir, :members => members})
  end

  defp save_key(key, base_dir) do
    File.mkdir_p(base_dir)
    File.write(base_dir <> "key.bin", key, [:binary])
  end

  defp start_link(key, config) do
    self_ip = get_self_ip()

    init_config =
      Map.merge(
        %{
          :ip => self_ip,
          :base_dir => ".",
          :artifact_size => 256_000,
          :system_key => key,
          :members => %{}
        },
        config
      )

    Agent.start_link(fn -> init_config end, name: __MODULE__)
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
      getMembersValues()
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
    createDir(conf.base_dir)

    Agent.update(__MODULE__, fn state ->
      %{
        :ip => state.ip,
        :artifact_size => state.artifact_size,
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
    Agent.get(__MODULE__, & &1.members)
  end

  def getArtifactSize do
    Agent.get(__MODULE__, & &1.artifact_size)
  end

  def getMembersInfo(members) do
    data =
      members
      |> Map.keys()
      |> Enum.reduce(<<>>, fn key, acc ->
        value = Map.get(members, key)
        acc <> key <> <<0>> <> value.base_dir <> <<0>> <> value.addrs <> <<0>>
      end)

    binary_part(data, 0, byte_size(data) - 1)
  end

  def init_members(members_info) do
    members_info
    |> Map.keys()
    |> Enum.reduce(members_info, fn key, acc ->
      {:ok, newMap} =
        Map.get_and_update(acc, key, fn info ->
          {:ok, Member.new(info)}
        end)

      newMap
    end)
  end

  def getSelfMember do
    %{
      UUID.uuid4() =>
        Member.new(%{
          :key => getSystemKey(),
          :addrs => get_IP(),
          :base_dir => get_base_dir(),
          :artifact_size => getArtifactSize()
        })
    }
  end

  def getMembersValues do
    getMembers() |> Map.values()
  end

  def hasMember(key) do
    getMembers() |> Map.has_key?(key)
  end

  defp getRandomMember do
    getMembersValues() |> Enum.random()
  end
end
