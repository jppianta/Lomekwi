defmodule LomekwiConfig do
  def config do
    %{
      :baseDir => "./test/mock_components/",
      :artifactSize => 256000
    }
  end
end