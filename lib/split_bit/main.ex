defmodule SplitBit do
  @moduledoc """
    Manages Key and Member constructions
  """

  use Agent
  require Logger

  def new_system(config \\ %{}) do
    Logger.add_backend({LoggerFileBackend, :info})

    Logger.configure_backend({LoggerFileBackend, :info},
      path: "./log/log.log"
    )

    start_server(8085)
    SplitBit.Client.new_system(Map.merge(%{:base_dir => "./test/mock_components/a/"}, config))
  end

  def join_system(system_member_ip, config \\ %{}, port \\ 8085) do
    start_server(port)

    SplitBit.Client.join_system(
      Map.merge(%{:base_dir => "./test/mock_components/"}, config),
      system_member_ip
    )
  end

  defp start_server(port_number) do
    # List all child processes to be supervised
    children = [
      Plug.Cowboy.child_spec(scheme: :http, plug: MemberApp.Router, options: [port: port_number])
    ]

    opts = [strategy: :one_for_one, name: MemberApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
