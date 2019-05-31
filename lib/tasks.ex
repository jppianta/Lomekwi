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
    Lomekwi.new_system()
    Lomekwi.Client.splitFile("inputFile.txt")
    Lomekwi.Client.mountFile("inputFile.txt", "./test/output.txt")
  end
end

# defmodule Mix.Tasks.MountFile do
#   use Mix.Task

#   @impl Mix.Task
#   def run(_args) do
#     Lomekwi.init()
#     Lomekwi.put("m1", %{:baseDir => "./test/mock_components/m1/"})
#     Lomekwi.put("m2", %{:baseDir => "./test/mock_components/m2/"})
#     Lomekwi.put("m3", %{:baseDir => "./test/mock_components/m3/"})
#     Lomekwi.put("m4", %{:baseDir => "./test/mock_components/m4/"})
#     Lomekwi.put("m5", %{:baseDir => "./test/mock_components/m5/"})
#     Lomekwi.put("m6", %{:baseDir => "./test/mock_components/m6/"})
#     Lomekwi.put("m7", %{:baseDir => "./test/mock_components/m7/"})
#     Lomekwi.splitFile("m1", "inputFile.txt", "./test/mock_files/")
#     IO.inspect(Lomekwi.mountFile("inputFile.txt", "./test/mock_components/inputFile.txt"))
#   end
# end

# defmodule Mix.Tasks.DeleteInput do
#   use Mix.Task

#   @impl Mix.Task
#   def run(_args) do
#     File.rm("./test/mock_files/inputFile.txt")
#   end
# end
