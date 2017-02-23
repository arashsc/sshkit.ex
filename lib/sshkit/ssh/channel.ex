defmodule SSHKit.SSH.Channel do
  alias SSHKit.SSH.Channel

  defstruct [:connection, :type, :id]

  @doc """
  Opens a channel on an SSH connection.

  On success, returns `{:ok, channel}`, where `channel` is a `Channel` struct.
  Returns `{:error, reason}` if a failure occurs.

  For more details, see [`:ssh_connection.session_channel/4`](http://erlang.org/doc/man/ssh_connection.html#session_channel-4).

  ## Options

  * `:type` - the type of the channel, defaults to `:session`
  * `:timeout` - defaults to `:infinity`
  * `:initial_window_size` - defaults to 128 KiB
  * `:max_packet_size` - defaults to 32 KiB
  """
  def open(connection, options \\ []) do
    type = Keyword.get(options, :type, :session)
    timeout = Keyword.get(options, :timeout, :infinity)
    ini_window_size = Keyword.get(options, :initial_window_size, 128 * 1024)
    max_packet_size = Keyword.get(options, :max_packet_size, 32 * 1024)

    case :ssh_connection.session_channel(connection.ref, ini_window_size, max_packet_size, timeout) do
      {:ok, id} -> {:ok, %Channel{connection: connection, type: type, id: id}}
      other -> other
    end
  end

  @doc """
  Closes an SSH channel.

  Returns `:ok`.

  For more details, see [`:ssh_connection.close/2`](http://erlang.org/doc/man/ssh_connection.html#close-2).
  """
  def close(channel) do
    :ssh_connection.close(channel.connection.ref, channel.id)
  end

  @doc """
  Executes a command on the remote host.

  Returns `:success`, `:failure` or `{:error, reason}`.

  For more details, see [`:ssh_connection.exec/4`](http://erlang.org/doc/man/ssh_connection.html#exec-4).

  ## Processing channel messages

  `loop/4` may be used to process any channel messages received as a result of
  executing `command` on the remote.
  """
  def exec(channel, command, timeout \\ :infinity) do
    :ssh_connection.exec(channel.connection.ref, channel.id, command, timeout)
  end

  @doc """
  Sends data across an open SSH channel.

  Returns `:ok`, `{:error, :timeout}` or `{:error, :closed}`.

  For more details, see [`:ssh_connection.send/5`](http://erlang.org/doc/man/ssh_connection.html#send-5).
  """
  def send(channel, type \\ 0, data, timeout \\ :infinity) do
    :ssh_connection.send(channel.connection.ref, channel.id, type, data, timeout)
  end

  @doc """
  Sends an EOF message on an open SSH channel.

  Returns `:ok` or `{:error, :closed}`.

  For more details, see [`:ssh_connection.send_eof/2`](http://erlang.org/doc/man/ssh_connection.html#send_eof-2).
  """
  def eof(channel) do
    :ssh_connection.send_eof(channel.connection.ref, channel.id)
  end
end
