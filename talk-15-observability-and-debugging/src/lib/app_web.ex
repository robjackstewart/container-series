defmodule AppWeb do
  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]

      import Plug.Conn
      unquote(verified_routes())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def endpoint do
    quote do
      use Phoenix.Endpoint, otp_app: :app
    end
  end

  defp verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: AppWeb.Endpoint,
        router: AppWeb.Router,
        statics: []
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
