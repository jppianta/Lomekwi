defmodule MemberTest do
  def findArtifacts(fileName, dirPath) do
    {:ok, files} = File.ls(dirPath)

    data =
      Enum.reduce(files, %{:vector => nil, :artifacts => []}, fn file, currData ->
        if not File.dir?(file) and artifact?(file) do
          artifact = getArtifactDetails(file)

          if artifact.fileName == fileName do
            if artifact.slice === "vector" do
              %{
                :vector => artifact,
                :artifacts => currData.artifacts
              }
            else
              %{
                :vector => currData.vector,
                :artifacts => currData.artifacts ++ [artifact]
              }
            end
          else
            currData
          end
        else
          currData
        end
      end)

    %{
      :artifacts =>
        Enum.sort(data.artifacts, &(String.to_integer(&1.slice) <= String.to_integer(&2.slice))),
      :vector => data.vector
    }
  end

  defp artifact?(file) do
    String.ends_with?(file, ".ats")
  end

  defp getArtifactDetails(art) do
    pattern = :binary.compile_pattern(["__", ".ats"])
    [slice | fileName] = String.split(art, pattern)

    %{
      :slice => slice,
      :fileName => List.to_string(fileName),
      :artifactName => art
    }
  end
end
