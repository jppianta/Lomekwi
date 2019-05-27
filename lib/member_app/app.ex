defmodule MemberApp do
  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: MemberApp.TaskSupervisor},
      {Task, fn -> MemberApp.Server.accept(4040) end}
    ]

    opts = [strategy: :one_for_one, name: MemberApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
