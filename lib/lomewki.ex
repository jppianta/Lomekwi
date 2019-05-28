defmodule Lomekwi do
  @moduledoc """
    Manages Key and Member constructions
  """

  use Agent
  require Logger

  def init do
    FileManager.new_system(%{:base_dir => "./test/mock_components/"})
    start_server()
  end

  defp start_server() do
    # List all child processes to be supervised
    children = [
      Plug.Cowboy.child_spec(scheme: :http, plug: MemberApp.Router, options: [port: 8085])
    ]

    opts = [strategy: :one_for_one, name: MemberApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
