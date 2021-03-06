defmodule MemberApp.Router do
  use Plug.Router
  use Plug.ErrorHandler
  use Plug.Debugger
  require Logger
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

    members = Map.merge(SplitBit.Client.getSelfMember(), SplitBit.Client.getMembers())

    SplitBit.Client.new_member(addrs, config)

    send_resp(
      conn,
      200,
      SplitBit.Client.getSystemKey() <>
        <<0>> <>
        to_string(SplitBit.Client.getArtifactSize()) <>
        <<0>> <> SplitBit.Client.getMembersInfo(members)
    )
  end

  post "/find_artifact" do
    {:ok, body, _req0} = read_body(conn)
    body = Jason.decode!(body)

    Task.start(fn ->
      SplitBit.FileManager.findArtifacts(Map.get(body, "fileName"), Map.get(body, "send_to"))
    end)

    send_resp(conn, 200, "FindingArtifacts")
  end

  post "/receive_artifact" do
    {:ok, body, _req0} = read_body(conn)

    artifact = %{
      :fileName => binary_part(body, 0, 32) |> parseName() |> to_string(),
      :slice => binary_part(body, 32, 16) |> parseName() |> parseSlice(),
      :content => binary_part(body, 48, byte_size(body) - 48)
    }

    Task.start(fn ->
      MemberApp.FileAcc.save_artifact(artifact)
    end)

    send_resp(conn, 200, "Artifact Collected")
  end

  post "/save_artifact" do
    {:ok, body, _req0} = read_body(conn)

    Task.start(fn ->
      artifact = %{
        :fileName => binary_part(body, 0, 32) |> parseName() |> to_string(),
        :slice => binary_part(body, 32, 16) |> parseName() |> parseSlice(),
        :content => binary_part(body, 48, byte_size(body) - 48)
      }

      SplitBit.FileManager.save_artifact(artifact)
    end)

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
    Logger.error("Package Error")
    send_resp(conn, conn.status, "Something went wrong")
  end

  # "Default" route that will get called when no other route is matched

  match _ do
    send_resp(conn, 404, "not found")
  end
end
