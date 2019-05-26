defmodule Mix.Tasks.PrepComponent do
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    File.rm_rf(mockComponentFolder() <> ".")
    filePath = mockComponentFolder() <> "inputFile.txt"
    File.write(filePath, "Test")
  end

  defp mockComponentFolder do
    "./test/mock_components/"
  end
end

defmodule Mix.Tasks.CreateArtifacts do
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    member = Lomekwi.init(%{})
    member.splitFile.("inputFile.txt")
  end
end

defmodule Mix.Tasks.DeleteInput do
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    filePath = mockComponentFolder() <> "inputFile.txt"
    File.rm(filePath)
  end

  defp mockComponentFolder do
    "./test/mock_components/"
  end
end

defmodule Mix.Tasks.MountFile do
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    member = Lomekwi.init(%{})
    member.mountFile.("inputFile.txt")
  end
end
