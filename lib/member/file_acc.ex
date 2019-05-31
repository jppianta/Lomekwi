defmodule MemberApp.FileAcc do
  use Agent
  require Logger

  def start_link(opts) do
    artifact_number = Enum.at(opts, 0)
    output_path = Enum.at(opts, 1)
    system_key = Enum.at(opts, 2)

    Logger.info("Number of Artifacts: #{artifact_number}")

    arts =
      Enum.reduce(1..artifact_number, {}, fn _i, acc ->
        Tuple.append(acc, nil)
      end)

    Agent.start_link(
      fn ->
        %{
          :artifacts => %{:artifacts => arts, :vector => nil},
          :output_path => output_path,
          :system_key => system_key
        }
      end,
      name: __MODULE__
    )
  end

  defp create_file do
    arts = get_artifacts()

    data = %{
      :vector => arts.vector,
      :artifacts => Tuple.to_list(arts.artifacts)
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
        Logger.info "Mount Completed"
    end
  end

  def save_artifact(artifact) do
    Agent.update(__MODULE__, fn state ->
      if artifact.slice == "vector" do
        %{
          :system_key => state.system_key,
          :output_path => state.output_path,
          :artifacts => %{:artifacts => state.artifacts.artifacts, :vector => artifact}
        }
      else
        %{
          :system_key => state.system_key,
          :output_path => state.output_path,
          :artifacts => %{
            :artifacts => put_elem(state.artifacts.artifacts, artifact.slice, artifact),
            :vector => state.artifacts.vector
          }
        }
      end
    end)

    show_info()

    if read_all?() do
      Logger.info("Read All")
      create_file()
    end
  end

  defp show_info do
    arts_list =
      get_artifacts().artifacts
      |> Tuple.to_list()

    accepted =
      Enum.reduce(arts_list, 0, fn i, acc ->
        if i != nil do
          acc + 1
        else
          acc
        end
      end)

    Logger.info("#{accepted / length(arts_list) * 100}%")
  end

  defp read_all? do
    get_artifacts().artifacts
    |> Tuple.to_list()
    |> Enum.reduce(true, fn val, acc ->
      acc and val != nil
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
