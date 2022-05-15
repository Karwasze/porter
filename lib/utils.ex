defmodule Utils do
  def search(query) do
    case System.cmd("yt-dlp", ["ytsearch:#{query}", "--flat-playlist", "--print", "url"]) do
      {url, 0} -> {:ok, url}
      {error, _} -> {:err, error}
    end
  end
end
