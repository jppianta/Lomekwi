defmodule LomekwiConfig do
  def config do
    %{
      :baseDir => "./test/mock_components/",
      :artifactSize => 256_000
    }
  end
end
