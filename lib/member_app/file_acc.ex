defmodule MemberApp.FileAcc do
  use Agent

  def start_link(opts) do
    member_keys = Enum.at(opts, 0)
    output_path = Enum.at(opts, 1)
    system_key = Enum.at(opts, 2)

    members =
      Enum.reduce(member_keys, %{}, fn key, acc ->
        Map.merge(acc, %{key => false})
      end)

    Agent.start_link(
      fn ->
        %{
          :artifacts => %{:artifacts => [], :vector => nil},
          :members => members,
          :output_path => output_path,
          :system_key => system_key
        }
      end,
      name: __MODULE__
    )
  end

  def member_complete(key) do
    Agent.update(__MODULE__, fn state ->
      %{
        :system_key => state.system_key,
        :output_path => state.output_path,
        :artifacts => state.artifacts,
        :members => Map.merge(state.members, %{key => true})
      }
    end)

    if read_all?() do
      create_file()
    end
  end

  defp create_file do
    arts = get_artifacts()

    data = %{
      :vector => arts.vector,
      :artifacts =>
        Enum.sort(arts.artifacts, &(&1.slice < &2.slice))
    }

    mountFile(data)
  end

  defp mountFile(artifacts) do
    case File.open(get_output_path(), [:binary, :write]) do
      {:ok, file} ->
        data =
          Enum.reduce(artifacts.artifacts, <<>>, fn artifact, currData ->
            currData <> artifact.content
          end)

        case ExCrypto.decrypt(get_system_key(), artifacts.vector.content, data) do
          {:ok, decData} ->
            IO.binwrite(file, decData)
        end

        File.close(file)
    end
  end

  def save_artifact(artifact) do
    Agent.update(__MODULE__, fn state ->
      if artifact.slice == "vector" do
        %{
          :system_key => state.system_key,
          :output_path => state.output_path,
          :artifacts => %{:artifacts => state.artifacts.artifacts, :vector => artifact},
          :members => state.members
        }
      else
        %{
          :system_key => state.system_key,
          :output_path => state.output_path,
          :artifacts => %{
            :artifacts => state.artifacts.artifacts ++ [artifact],
            :vector => state.artifacts.vector
          },
          :members => state.members
        }
      end
    end)
  end

  defp read_all? do
    Agent.get(__MODULE__, & &1.members)
    |> Map.values()
    |> Enum.reduce(true, fn val, acc ->
      acc and val
    end)
  end

  defp get_artifacts do
    Agent.get(__MODULE__, & &1.artifacts)
  end

  defp get_system_key do
    Agent.get(__MODULE__, & &1.system_key)
  end

  defp get_output_path do
    Agent.get(__MODULE__, & &1.output_path)
  end
end
