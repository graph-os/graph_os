defmodule GraphOS.Component.Context do
  @moduledoc """
  Defines a context struct that flows through component pipelines.

  The context is similar to `Plug.Conn` and holds request/response data as it
  passes through a series of components. Each component can transform the context
  by adding assigns, setting results, or marking it as halted.
  """

  @type t :: %__MODULE__{
          assigns: map(),
          halted: boolean(),
          params: map(),
          request_id: binary(),
          result: any(),
          error: nil | {atom(), binary()},
          metadata: map(),
          private: map()
        }

  defstruct assigns: %{},
            halted: false,
            params: %{},
            request_id: nil,
            result: nil,
            error: nil,
            metadata: %{},
            private: %{}

  @doc """
  Creates a new context with the given parameters.

  ## Options
    * `:params` - Initial parameters for the request (default: %{})
    * `:request_id` - Unique ID for the request (default: generated UUID)
    * `:metadata` - Additional metadata for the request (default: %{})

  ## Examples
      iex> Context.new(params: %{name: "test"})
      %Context{params: %{name: "test"}, request_id: "..."}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    request_id = Keyword.get(opts, :request_id) || generate_request_id()
    params = Keyword.get(opts, :params, %{})
    metadata = Keyword.get(opts, :metadata, %{})

    %__MODULE__{
      request_id: request_id,
      params: params,
      metadata: metadata
    }
  end

  @doc """
  Adds values to the context's assigns map.

  ## Examples
      iex> context = Context.new()
      iex> context = Context.assign(context, :user_id, 123)
      iex> context.assigns.user_id
      123
      
      iex> context = Context.new()
      iex> context = Context.assign(context, user_id: 123, role: :admin)
      iex> context.assigns
      %{user_id: 123, role: :admin}
  """
  @spec assign(t(), atom(), any()) :: t()
  def assign(%__MODULE__{} = context, key, value) when is_atom(key) do
    %{context | assigns: Map.put(context.assigns, key, value)}
  end

  @spec assign(t(), Enumerable.t()) :: t()
  def assign(%__MODULE__{} = context, keyword) when is_list(keyword) or is_map(keyword) do
    %{context | assigns: Map.merge(context.assigns, Map.new(keyword))}
  end

  @doc """
  Stores a successful result in the context.

  ## Examples
      iex> context = Context.new()
      iex> context = Context.put_result(context, %{data: [1, 2, 3]})
      iex> context.result
      %{data: [1, 2, 3]}
  """
  @spec put_result(t(), any()) :: t()
  def put_result(%__MODULE__{} = context, result) do
    %{context | result: result, error: nil}
  end

  @doc """
  Stores an error in the context and optionally halts the pipeline.

  ## Options
    * `:halt` - Whether to halt the pipeline (default: true)

  ## Examples
      iex> context = Context.new()
      iex> context = Context.put_error(context, :not_found, "Resource not found")
      iex> context.error
      {:not_found, "Resource not found"}
      iex> context.halted
      true
      
      iex> context = Context.new()
      iex> context = Context.put_error(context, :validation, "Invalid input", halt: false)
      iex> context.error
      {:validation, "Invalid input"}
      iex> context.halted
      false
  """
  @spec put_error(t(), atom(), binary(), keyword()) :: t()
  def put_error(%__MODULE__{} = context, type, message, opts \\ [])
      when is_atom(type) and is_binary(message) do
    should_halt = Keyword.get(opts, :halt, true)

    context = %{context | error: {type, message}}
    if should_halt, do: halt(context), else: context
  end

  @doc """
  Halts the component pipeline, preventing further components from running.

  ## Examples
      iex> context = Context.new()
      iex> context = Context.halt(context)
      iex> context.halted
      true
  """
  @spec halt(t()) :: t()
  def halt(%__MODULE__{} = context) do
    %{context | halted: true}
  end

  @doc """
  Checks if the context has been halted.

  ## Examples
      iex> context = Context.new()
      iex> Context.halted?(context)
      false
      
      iex> context = Context.new() |> Context.halt()
      iex> Context.halted?(context)
      true
  """
  @spec halted?(t()) :: boolean()
  def halted?(%__MODULE__{halted: halted}), do: halted

  @doc """
  Adds values to the context's private map for internal use by components.

  This is useful for storing data that should not be exposed in the final result
  but needs to be passed between components.

  ## Examples
      iex> context = Context.new()
      iex> context = Context.put_private(context, :auth_token, "abc123")
      iex> context.private.auth_token
      "abc123"
  """
  @spec put_private(t(), atom(), any()) :: t()
  def put_private(%__MODULE__{} = context, key, value) when is_atom(key) do
    %{context | private: Map.put(context.private, key, value)}
  end

  @doc """
  Adds multiple values to the context's private map.

  ## Examples
      iex> context = Context.new()
      iex> context = Context.put_private(context, auth_token: "abc123", session_id: "xyz")
      iex> context.private
      %{auth_token: "abc123", session_id: "xyz"}
  """
  @spec put_private(t(), Enumerable.t()) :: t()
  def put_private(%__MODULE__{} = context, keyword) when is_list(keyword) or is_map(keyword) do
    %{context | private: Map.merge(context.private, Map.new(keyword))}
  end

  @doc """
  Adds metadata to the context.

  ## Examples
      iex> context = Context.new()
      iex> context = Context.put_metadata(context, :timestamp, 1615000000)
      iex> context.metadata.timestamp
      1615000000
  """
  @spec put_metadata(t(), atom(), any()) :: t()
  def put_metadata(%__MODULE__{} = context, key, value) when is_atom(key) do
    %{context | metadata: Map.put(context.metadata, key, value)}
  end

  @doc """
  Adds multiple metadata values to the context.

  ## Examples
      iex> context = Context.new()
      iex> context = Context.put_metadata(context, timestamp: 1615000000, source: :api)
      iex> context.metadata
      %{timestamp: 1615000000, source: :api}
  """
  @spec put_metadata(t(), Enumerable.t()) :: t()
  def put_metadata(%__MODULE__{} = context, keyword) when is_list(keyword) or is_map(keyword) do
    %{context | metadata: Map.merge(context.metadata, Map.new(keyword))}
  end

  @doc """
  Checks if the context has an error.

  ## Examples
      iex> context = Context.new()
      iex> Context.error?(context)
      false
      
      iex> context = Context.new() |> Context.put_error(:not_found, "Resource not found")
      iex> Context.error?(context)
      true
  """
  @spec error?(t()) :: boolean()
  def error?(%__MODULE__{error: nil}), do: false
  def error?(%__MODULE__{error: _}), do: true

  @doc """
  Returns the error type and message if the context has an error, nil otherwise.

  ## Examples
      iex> context = Context.new()
      iex> Context.error(context)
      nil
      
      iex> context = Context.new() |> Context.put_error(:not_found, "Resource not found")
      iex> Context.error(context)
      {:not_found, "Resource not found"}
  """
  @spec error(t()) :: nil | {atom(), binary()}
  def error(%__MODULE__{error: error}), do: error

  # Generate a unique request ID
  defp generate_request_id do
    uuid = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    # Format as UUID
    <<a::binary-size(8), b::binary-size(4), c::binary-size(4), d::binary-size(4),
      e::binary-size(12)>> = uuid

    "#{a}-#{b}-#{c}-#{d}-#{e}"
  end
end
