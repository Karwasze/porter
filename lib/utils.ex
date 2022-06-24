defmodule Utils do
  def search(query) do
    case System.cmd("yt-dlp", [
           "ytsearch:#{query}",
           "--flat-playlist",
           "--print",
           "url",
           "--print",
           "filename"
         ]) do
      {result, 0} ->
        result = String.split(result, ~r{\n}, trim: true)
        url = List.first(result)

        name =
          List.last(result)
          |> String.split(" ")
          |> List.delete_at(-1)
          |> Enum.join(" ")

        {url, name}
        |> IO.inspect()

      {error, _} ->
        {:err, error}
    end
  end
end
