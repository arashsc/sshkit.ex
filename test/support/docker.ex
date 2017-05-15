defmodule Docker do
  @moduledoc false

  defmodule Error do
    defexception [:command, :args, :status, :output]

    def message(%{command: command, args: args, status: status, output: output}) do
      "Failed on docker #{Enum.join([command | args], " ")} (#{status}):\n#{output}"
    end
  end

  @doc """
  Checks whether docker is available and ready to be run.

  Returns false if:

  1. Docker is not installed or the `docker` command cannot be found.
  2. you're on Mac or Windows, but Docker Machine is not set up.

  Otherwise returns true and Docker should be ready for use.
  """
  def ready? do
    {:ok, _} = HTTPoison.start()

    case cmd("info", []) do
      {_, 0} -> true
      _ -> false
    end
  end

  @doc """
  Determines the Docker host address.

  Checks for the `DOCKER_HOST` environment variable set by Docker Machine or
  falls back to `127.0.0.1`.

  The containers we start for testing publish their local SSH port (22) to
  random ports on the host machine. On Mac and Windows the host machine is
  the Docker Machine `DOCKER_HOST`. Systems running Docker Engine directly
  publish ports to localhost (127.0.0.1) directly.

  Returns the name (or IP address) of the configured Docker host.
  """
  def host do
    case System.get_env("DOCKER_HOST") do
      addr when is_binary(addr) -> Map.get(URI.parse(addr), :host)
      nil -> "127.0.0.1"
    end
  end

  @doc """
  Builds a tagged Docker image from a Dockerfile.

  Returns the image ID.
  """
  def build!(tag, path) do
    cmd!("build", ["--quiet", "--tag", tag, path])
  end

  @doc """
  Runs a command in a new container.

  Returns the command output.
  """
  def run!(options \\ [], image, command \\ nil, args \\ [])

  def run!(options, image, nil, []) do
    cmd!("run", options ++ [image])
  end

  def run!(options, image, command, args) do
    body = Poison.encode!(%{"Image" => image, "Cmd" => [command | args], "ExposedPorts" => %{"22/tcp" => %{}}, "HostConfig" => %{"PublishAllPorts" => true, "AutoRemove" => true}})
    {:ok, response} = req(:post, "https://192.168.99.100:2376/v1.29/containers/create", body)
    %{"Id" => id} = Poison.decode!(response.body)

    body = Poison.encode!(%{})
    {:ok, _} = req(:post, "https://192.168.99.100:2376/v1.29/containers/#{id}/start", body)

    id
  end

  @doc """
  Runs a command in a running container.

  Returns the command output.
  """
  def exec!(options \\ [], container, command, args \\ []) do
    body = Poison.encode!(%{"Cmd" => [command | args]})
    {:ok, response} = req(:post, "https://192.168.99.100:2376/v1.29/containers/#{container}/exec", body)
    %{"Id" => id} = Poison.decode!(response.body)

    body = Poison.encode!(%{})
    {:ok, response} = req(:post, "https://192.168.99.100:2376/v1.29/exec/#{id}/start", body)
  end

  defp req(method, url, body) do
    headers = [{"Content-Type", "application/json"}]

    options = [ssl: [
      certfile: "/Users/pmeinhardt/.docker/machine/certs/cert.pem",
      keyfile: "/Users/pmeinhardt/.docker/machine/certs/key.pem",
      cacertfile: "/Users/pmeinhardt/.docker/machine/certs/ca.pem"]]

    HTTPoison.request(method, url, body, headers, options)
  end

  @doc """
  Kills one or more running containers.

  Returns a list of the killed containers' IDs.
  """
  def kill!(options \\ [], containers) do
    Enum.map(containers, fn id -> req(:post, "https://192.168.99.100:2376/v1.29/containers/#{id}/kill", "") end)
  end

  @doc """
  Runs a docker command with the given arguments.

  Returns a tuple containing the command output and exit status.

  For details, see [`System.cmd/3`](https://hexdocs.pm/elixir/System.html#cmd/3).
  """
  def cmd(command, args \\ []) do
    System.cmd("docker", [command | args], stderr_to_stdout: true)
  end

  @doc """
  Runs a docker command with the given arguments.

  Returns the command output or, if the command exits with a non-zero status,
  raises a `Docker.Error`.
  """
  def cmd!(command, args \\ []) do
    {output, status} = cmd(command, args)

    case status do
      0 -> String.trim(output)
      _ -> raise Error, command: command, args: args, status: status, output: output
    end
  end
end
