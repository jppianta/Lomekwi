defmodule LomekwiTest do
  use ExUnit.Case, async: true
  doctest Lomekwi

  defp mockComponentFolder do
    LomekwiConfig.config().base_dir
  end

  defp initMember do
    Lomekwi.init(%{})
  end

  defp clearFiles do
    File.rm_rf(mockComponentFolder() <> ".")
  end

  defp mountComponents do
    clearFiles()
    filePath = mockComponentFolder() <> "inputFile.txt"
    File.write(filePath, "Eu amo a Ianinha")
  end

  test "splitFile" do
    mountComponents()
    member = initMember()
    member.splitFile.("inputFile.txt")
    data = MemberTest.findArtifacts("inputFile.txt", mockComponentFolder())
    assert data.vector != nil
    assert length(data.artifacts) > 0
    clearFiles()
  end

  test "mountFile" do
    mountComponents()
    member = initMember()
    member.splitFile.("inputFile.txt")
    filePath = mockComponentFolder() <> "inputFile.txt"
    File.rm(filePath)
    member.mountFile.("inputFile.txt")
    {:ok, content} = File.read(filePath)
    assert content == "Eu amo a Ianinha"
    clearFiles()
  end
end
