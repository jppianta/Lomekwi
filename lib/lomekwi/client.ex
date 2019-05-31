defmodule Lomekwi.Client do
  use Agent
  require Logger

  # Client
  def new_system(config) do
    key = generateKey()
    save_key(key, config.base_dir)
    start_link(key, config)
  end

  # Client
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

  # Client
  defp save_key(key, base_dir) do
    File.mkdir_p(base_dir)
    File.write(base_dir <> "key.bin", key, [:binary])
  end

  # Client
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

    init_file_manager(init_config)
    Agent.start_link(fn -> init_config end, name: __MODULE__)
  end

  defp init_file_manager(config) do
    children = [{Lomekwi.FileManager, %{:base_dir => config.base_dir, :ip => config.ip}}]

    opts = [strategy: :one_for_one, name: Lomekwi.FileManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Client
  defp get_self_ip do
    {:ok, ifs} = :inet.getif()
    Enum.at(ifs, 0) |> elem(0) |> Tuple.to_list() |> Enum.join(".")
  end

  @doc """
    Gets a value from the `bucket` by `key` and splits the member file
  """
  # Client
  def splitFile(fileName, baseDir \\ get_base_dir()) do
    Logger.info("Spliting File: #{fileName}")
    arts = split(fileName, baseDir)
    Logger.info("Spliting Completed")
    Logger.info("Uploading File")

    Enum.reduce(arts, {0, 1}, fn artifact, acc ->
      createArtifact(artifact, elem(acc, 0))
      turn = (elem(acc, 0) + 1) |> Integer.mod(length(get_all_member_values()))
      ProgressBar.render(elem(acc, 1), length(arts), suffix: :count)
      {turn, elem(acc, 1) + 1}
    end)

    Logger.info("Uploading Completed")
  end

  # Client
  defp split(fileName, baseDir) do
    filePath = baseDir <> fileName
    {:ok, file} = File.open(filePath, [:binary, :read])
    data = IO.binread(file, :all)
    File.close(file)
    {:ok, {init_vector, cipher_text}} = ExCrypto.encrypt(getSystemKey(), data)
    size = byte_size(cipher_text)
    parts = div(size, getArtifactSize())
    rest = rem(size, getArtifactSize())

    artifacts =
      splitParts(parts, cipher_text, fileName) ++
        splitRest(rest, cipher_text, fileName, size, parts)

    create_metadata(fileName, %{:artifact_number => length(artifacts)})

    artifacts ++ [%{:fileName => fileName, :content => init_vector, :part => "vector"}]
  end

  defp create_metadata(fileName, info) do
    meta = %{:fileName => fileName, :content => Jason.encode!(info), :part => "meta"}

    get_all_member_values()
    |> Enum.each(fn member ->
      member.save_artifact.(meta)
    end)
  end

  # Client
  defp splitParts(parts, content, fileName) do
    if parts > 0 do
      Enum.map(0..(parts - 1), fn part ->
        partData = binary_part(content, part * getArtifactSize(), getArtifactSize())
        %{:fileName => fileName, :content => partData, :part => to_string(part)}
      end)
    else
      []
    end
  end

  # Client
  defp splitRest(rest, content, fileName, size, part) do
    if rest > 0 do
      partData = binary_part(content, size - rest, rest)
      [%{:fileName => fileName, :content => partData, :part => to_string(part)}]
    else
      []
    end
  end

  # Client
  def mountFile(fileName, newFilePath) do
    members = Map.merge(getMembers(), getSelfMember())

    info = read_metadata(fileName)

    children = [
      {MemberApp.FileAcc, [Map.get(info, "artifact_number"), newFilePath, getSystemKey()]}
    ]

    opts = [strategy: :one_for_one, name: MemberApp.FileAcc.Supervisor]
    Supervisor.start_link(children, opts)

    Logger.info("Downloading Artifacts")

    members
    |> Map.values()
    |> Enum.each(fn member ->
      member.findArtifacts.(fileName, get_IP())
    end)
  end

  defp read_metadata(fileName) do
    {:ok, content} = File.read(get_base_dir() <> "meta__" <> fileName <> ".ats")
    Jason.decode!(content)
  end

  # Client
  defp createArtifact(artifact, to) do
    member = get_all_member_values() |> Enum.at(to)
    member.save_artifact.(artifact)
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

  # Both
  def getSystemKey do
    Agent.get(__MODULE__, & &1.system_key)
  end

  # Both
  def get_base_dir do
    Agent.get(__MODULE__, & &1.base_dir)
  end

  # Both
  def get_IP do
    Agent.get(__MODULE__, & &1.ip)
  end

  # Client
  def getMembers do
    Agent.get(__MODULE__, & &1.members)
  end

  # Client
  def getArtifactSize do
    Agent.get(__MODULE__, & &1.artifact_size)
  end

  # Client
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

  # Client
  def getSelfMember do
    %{
      get_IP() =>
        Member.new(%{
          :key => getSystemKey(),
          :addrs => get_IP(),
          :base_dir => get_base_dir(),
          :artifact_size => getArtifactSize()
        })
    }
  end

  # Client
  def getMembersValues do
    getMembers() |> Map.values()
  end

  # # Client
  # defp getRandomMember do
  #   get_all_member_values() |> Enum.random()
  # end

  defp get_all_member_values do
    getMembersValues() ++ (getSelfMember() |> Map.values())
  end
end
