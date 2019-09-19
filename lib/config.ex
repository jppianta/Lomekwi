defmodule SplitBitConfig do
  def config do
    %{
      :base_dir => "./test/mock_components/",
      :artifact_size => 256_000
    }
  end
end
