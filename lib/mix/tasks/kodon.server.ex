defmodule Mix.Tasks.Kodon.Server do
  @moduledoc """
  Starts a local development server for the built site.

  ## Usage

      mix kodon.server          # serves on port 4000
      mix kodon.server 8080     # serves on custom port

  Serves static files from the output directory with proper MIME types.
  """

  use Mix.Task

  @shortdoc "Start a local dev server for the AHCIP site"

  @mime_types %{
    ".html" => "text/html; charset=utf-8",
    ".css" => "text/css; charset=utf-8",
    ".js" => "application/javascript",
    ".json" => "application/json",
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif" => "image/gif",
    ".svg" => "image/svg+xml",
    ".ico" => "image/x-icon",
    ".woff" => "font/woff",
    ".woff2" => "font/woff2"
  }

  @impl Mix.Task
  def run(args) do
    port =
      case args do
        [port_str | _] -> String.to_integer(port_str)
        [] -> 4000
      end

    output_dir =
      Application.get_env(:kodon, :output_dir, "output")
      |> Path.expand()

    unless File.dir?(output_dir) do
      Mix.raise("Output directory #{output_dir} not found. Run `mix kodon.build` first.")
    end

    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :http_bin, active: false, reuseaddr: true])

    Mix.shell().info("AHCIP dev server running at http://localhost:#{port}")
    Mix.shell().info("Serving files from #{output_dir}")
    Mix.shell().info("Press Ctrl+C to stop.\n")

    accept_loop(socket, output_dir)
  end

  defp accept_loop(socket, output_dir) do
    {:ok, client} = :gen_tcp.accept(socket)
    Task.start(fn -> handle_connection(client, output_dir) end)
    accept_loop(socket, output_dir)
  end

  defp handle_connection(socket, output_dir) do
    case read_request(socket) do
      {:ok, path} ->
        serve_file(socket, output_dir, path)

      :error ->
        send_response(socket, 400, "text/plain", "Bad Request")
    end

    :gen_tcp.close(socket)
  end

  defp read_request(socket) do
    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, {:http_request, :GET, {:abs_path, path}, _}} ->
        # Consume remaining headers
        drain_headers(socket)
        {:ok, URI.decode(to_string(path))}

      {:ok, {:http_request, _method, {:abs_path, path}, _}} ->
        drain_headers(socket)
        {:ok, URI.decode(to_string(path))}

      _ ->
        :error
    end
  end

  defp drain_headers(socket) do
    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, :http_eoh} -> :ok
      {:ok, {:http_header, _, _, _, _}} -> drain_headers(socket)
      _ -> :ok
    end
  end

  defp serve_file(socket, output_dir, path) do
    # Normalize path: strip query string, resolve /
    path = path |> String.split("?") |> hd()

    file_path =
      cond do
        path == "/" ->
          Path.join(output_dir, "index.html")

        String.ends_with?(path, "/") ->
          Path.join(output_dir, path <> "index.html")

        true ->
          full = Path.join(output_dir, path)

          if File.dir?(full) do
            Path.join(full, "index.html")
          else
            full
          end
      end

    # Prevent directory traversal
    file_path = Path.expand(file_path)

    unless String.starts_with?(file_path, output_dir) do
      send_response(socket, 403, "text/plain", "Forbidden")
    else
      case File.read(file_path) do
        {:ok, content} ->
          ext = Path.extname(file_path)
          content_type = Map.get(@mime_types, ext, "application/octet-stream")
          log_request(200, path)
          send_response(socket, 200, content_type, content)

        {:error, _} ->
          log_request(404, path)
          send_response(socket, 404, "text/html; charset=utf-8", not_found_html(path))
      end
    end
  end

  defp send_response(socket, status, content_type, body) do
    status_text =
      case status do
        200 -> "OK"
        400 -> "Bad Request"
        403 -> "Forbidden"
        404 -> "Not Found"
        _ -> "Unknown"
      end

    response = [
      "HTTP/1.1 #{status} #{status_text}\r\n",
      "Content-Type: #{content_type}\r\n",
      "Content-Length: #{byte_size(body)}\r\n",
      "Connection: close\r\n",
      "\r\n",
      body
    ]

    :gen_tcp.send(socket, response)
  end

  defp log_request(status, path) do
    Mix.shell().info("  #{status} #{path}")
  end

  defp not_found_html(path) do
    """
    <!DOCTYPE html>
    <html><head><title>404 Not Found</title></head>
    <body><h1>404 Not Found</h1><p>#{path}</p>
    <p><a href="/">Back to home</a></p></body></html>
    """
  end
end
