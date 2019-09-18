defmodule Utils.Loader do
  def split_progress(cur, total) do
    format = [
      bar_color: IO.ANSI.magenta,
      bar: ".:"
    ]
    ProgressBar.render(cur, total, format)
  end

  def split_load(file_name, fun) do
    format = [
      frames: ["/" , "-", "\\", "|"],  # Or an atom, see below
      text: "Spliting File: #{file_name}",
      done: "Spliting Complete 👌",
      spinner_color: IO.ANSI.magenta,
      interval: 100,  # milliseconds between frames
    ]
    ProgressBar.render_spinner format, fun
  end

  def upload_progress(cur, total) do
    format = [
      bar_color: IO.ANSI.green,
      bar: ".:"
    ]
    ProgressBar.render(cur, total, format)
  end

  def upload_load(file_name, fun) do
    format = [
      frames: ["/" , "-", "\\", "|"],  # Or an atom, see below
      text: "Uploading File: #{file_name}",
      done: "Upload Complete 👌",
      spinner_color: IO.ANSI.green,
      interval: 100,  # milliseconds between frames
    ]
    ProgressBar.render_spinner format, fun
  end

  def download_progress(cur, total) do
    format = [
      bar_color: IO.ANSI.yellow,
      bar: ".:"
    ]
    ProgressBar.render(cur, total, format)
  end

  def download_load(file_name, fun) do
    format = [
      frames: ["/" , "-", "\\", "|"],  # Or an atom, see below
      text: "Downloading File: #{file_name}",
      done: "Download Complete 👌",
      spinner_color: IO.ANSI.yellow,
      interval: 100,  # milliseconds between frames
    ]
    ProgressBar.render_spinner format, fun
  end

  def mount_progress(cur, total) do
    format = [
      bar_color: IO.ANSI.red,
      bar: ".:"
    ]
    ProgressBar.render(cur, total, format)
  end

  def mount_load(file_name, fun) do
    format = [
      frames: ["/" , "-", "\\", "|"],  # Or an atom, see below
      text: "Mounting File: #{file_name}",
      done: "Mounting Complete 👌",
      spinner_color: IO.ANSI.red,
      interval: 100,  # milliseconds between frames
    ]
    ProgressBar.render_spinner format, fun
  end
end