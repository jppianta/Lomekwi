defmodule Mix.Tasks.PrepComponent do
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    File.rm_rf("./test/mock_components")
    File.rm_rf("./test/mock_files/*")
    File.mkdir_p("./test/mock_components/a/")
    filePath = "./test/mock_components/a/inputFile.txt"

    File.write(
      filePath,
      Enum.reduce(1..100_000_000, "", fn _a, acc -> acc <> "Eu amo a Ianinha " end)
    )
  end
end

defmodule Mix.Tasks.TestBig do
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    SplitBit.new_system()
    SplitBit.Client.splitFile("inputFile.txt", "./test/mock_components/a/")
    SplitBit.Client.mountFile("inputFile.txt", "./test/mock_components/output.txt")
  end
end

# defmodule Mix.Tasks.MountFile do
#   use Mix.Task

#   @impl Mix.Task
#   def run(_args) do
#     SplitBit.init()
#     SplitBit.put("m1", %{:baseDir => "./test/mock_components/m1/"})
#     SplitBit.put("m2", %{:baseDir => "./test/mock_components/m2/"})
#     SplitBit.put("m3", %{:baseDir => "./test/mock_components/m3/"})
#     SplitBit.put("m4", %{:baseDir => "./test/mock_components/m4/"})
#     SplitBit.put("m5", %{:baseDir => "./test/mock_components/m5/"})
#     SplitBit.put("m6", %{:baseDir => "./test/mock_components/m6/"})
#     SplitBit.put("m7", %{:baseDir => "./test/mock_components/m7/"})
#     SplitBit.splitFile("m1", "inputFile.txt", "./test/mock_files/")
#     IO.inspect(SplitBit.mountFile("inputFile.txt", "./test/mock_components/inputFile.txt"))
#   end
# end

# defmodule Mix.Tasks.DeleteInput do
#   use Mix.Task

#   @impl Mix.Task
#   def run(_args) do
#     File.rm("./test/mock_files/inputFile.txt")
#   end
# end
