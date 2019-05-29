defmodule MemberApp.Router do
  use Plug.Router
  use Plug.ErrorHandler
  use Plug.Debugger
  require Logger
  plug(Plug.Logger, log: :debug)

  plug(:match)

  plug(:dispatch)

  post "/join_system" do
    {:ok, body, conn} = read_body(conn)

    body = Jason.decode!(body)

    addrs = Map.get(body, "addrs")

    config = %{
      :addrs => addrs,
      :base_dir => Map.get(body, "base_dir")
    }

    members = Map.merge(FileManager.getSelfMember(), FileManager.getMembers())

    FileManager.new_member(addrs, config)

    send_resp(
      conn,
      200,
      FileManager.getSystemKey() <>
        <<0>> <>
        to_string(FileManager.getArtifactSize()) <> <<0>> <> FileManager.getMembersInfo(members)
    )
  end

  post "/find_artifact" do
    {:ok, body, _req0} = read_body(conn)
    body = Jason.decode!(body)

    FileManager.findArtifacts(Map.get(body, "fileName"), Map.get(body, "send_to"))

    send_resp(conn, 200, "FindingArtifacts")
  end

  post "/receive_artifact" do
    {:ok, body, _req0} = read_body(conn)

    artifact = %{
      :fileName => binary_part(body, 0, 32) |> parseName() |> to_string(),
      :slice => binary_part(body, 32, 16) |> parseName() |> parseSlice(),
      :content => binary_part(body, 48, byte_size(body) - 48)
    }

    MemberApp.FileAcc.save_artifact(artifact)

    send_resp(conn, 200, "Artifact Collected")
  end

  post "/sent_all_artifact" do
    {:ok, body, conn} = read_body(conn)

    body = Jason.decode!(body)

    from = Map.get(body, "ip")

    MemberApp.FileAcc.member_complete(from)

    send_resp(conn, 200, "Artifact Collected")
  end

  post "/save_artifact" do
    {:ok, body, _req0} = read_body(conn)

    artifact = %{
      :fileName => binary_part(body, 0, 32) |> parseName() |> to_string(),
      :slice => binary_part(body, 32, 16) |> parseName() |> parseSlice(),
      :content => binary_part(body, 48, byte_size(body) - 48)
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
