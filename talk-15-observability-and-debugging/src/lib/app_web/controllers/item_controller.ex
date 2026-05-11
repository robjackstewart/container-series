defmodule AppWeb.ItemController do
  use AppWeb, :controller

  alias App.ItemStore
  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  def index(conn, _params) do
    Tracer.with_span "items.list" do
      items = ItemStore.get_all()
      Tracer.set_attributes([{"items.count", length(items)}])
      Logger.info(Jason.encode!(%{event: "items.list", count: length(items)}))
      json(conn, items)
    end
  end

  def show(conn, %{"id" => id}) do
    Tracer.with_span "items.show" do
      with {:ok, parsed_id} <- parse_id(id) do
        Tracer.set_attributes([{"item.id", parsed_id}])

        case ItemStore.get(parsed_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Not found"})

          item ->
            json(conn, item)
        end
      else
        :error ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid item id"})
      end
    end
  end

  def create(conn, params) do
    Tracer.with_span "items.create" do
      item = %{
        id: ItemStore.next_id(),
        name: Map.get(params, "name", "Unnamed"),
        description: Map.get(params, "description", "")
      }

      ItemStore.add(item)
      Tracer.set_attributes([{"item.id", item.id}])
      Logger.info(Jason.encode!(Map.put(item, :event, "items.create")))

      conn
      |> put_status(:created)
      |> json(item)
    end
  end

  def delete(conn, %{"id" => id}) do
    Tracer.with_span "items.delete" do
      with {:ok, parsed_id} <- parse_id(id) do
        case ItemStore.delete(parsed_id) do
          true -> send_resp(conn, :no_content, "")
          false -> conn |> put_status(:not_found) |> json(%{error: "Not found"})
        end
      else
        :error ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid item id"})
      end
    end
  end

  defp parse_id(id) do
    case Integer.parse(id) do
      {parsed_id, ""} -> {:ok, parsed_id}
      _ -> :error
    end
  end
end
