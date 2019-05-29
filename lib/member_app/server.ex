defmodule MemberApp.Router do
  use Plug.Router
  use Plug.ErrorHandler
  use Plug.Debugger
  require UUID
  require Logger
  plug(Plug.Logger, log: :debug)

  plug(:match)

  plug(:dispatch)

  post "/join_system" do
    {:ok, body, conn} = read_body(conn)

    body = Jason.decode!(body)

    key = UUID.uuid4()

    config = %{
      :addrs => Map.get(body, "addrs"),
      :base_dir => Map.get(body, "base_dir")
    }

    members = Map.merge(FileManager.getSelfMember(), FileManager.getMembers())

    FileManager.new_member(key, config)

    send_resp(
      conn,
      200,
      FileManager.getSystemKey() <>
        <<0>> <>
        to_string(FileManager.getArtifactSize()) <> <<0>> <> FileManager.getMembersInfo(members)
    )
  end

  post "/new_member" do
    {:ok, body, conn} = read_body(conn)

    body = Jason.decode!(body)

    key = UUID.uuid4()

    config = Map.merge(%{:addrs => "localhost"}, body)

    FileManager.new_member(key, config)

    send_resp(conn, 201, "created: #{get_in(body, ["message"])}")
  end

  post "/save_artifact" do
    Logger.info("Start Save Artifact")

    {:ok, body, _req0} = read_body(conn)

    artifact = %{
      :fileName => binary_part(body, 0, 32) |> parseName() |> to_string(),
      :slice => binary_part(body, 32, 16) |> parseName() |> parseSlice(),
      :content => binary_part(body, 50, div(bit_size(body), 8) - 50)
    }

    FileManager.save_artifact(artifact)
    send_resp(conn, 404, "End Save Artifact")
  end

  defp parseName(bits) do
    bits |> Binary.trim_trailing()
  end

  defp parseSlice(slice) do
    try do
      String.to_integer(slice)
    rescue
      ArgumentError -> slice
    end
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, conn.status, "Something went wrong")
  end

  # "Default" route that will get called when no other route is matched

  match _ do
    send_resp(conn, 404, "not found")
  end
end
