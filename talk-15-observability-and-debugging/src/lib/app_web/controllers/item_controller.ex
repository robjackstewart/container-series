defmodule AppWeb.ItemController do
  use Phoenix.Controller, formats: [:json]
  require OpenTelemetry.Tracer, as: Tracer
  require Logger

  alias App.ItemStore

  def index(conn, _params) do
    Tracer.with_span "items.list" do
      items = ItemStore.all()
      Tracer.set_attributes([{"items.count", length(items)}])
      Logger.info("Listed items", count: length(items))
      json(conn, items)
    end
  end

  def show(conn, %{"id" => id_str}) do
    case Integer.parse(id_str) do
      {id, ""} ->
        Tracer.with_span "items.show", %{attributes: [{"item.id", id}]} do
          case ItemStore.get(id) do
            nil ->
              Logger.warning("Item not found", item_id: id)
              conn |> put_status(404) |> json(%{error: "Item not found", id: id})

            item ->
              json(conn, item)
          end
        end

      _ ->
        conn |> put_status(400) |> json(%{error: "Invalid item id", id: id_str})
    end
  end

  def create(conn, params) do
    Tracer.with_span "items.create" do
      id = ItemStore.next_id()
      item = %{id: id, name: params["name"] || "Unnamed", description: params["description"] || ""}
      ItemStore.add(item)
      Tracer.set_attributes([{"item.id", id}, {"item.name", item.name}])
      Logger.info("Item created", item_id: id, item_name: item.name)
      conn |> put_status(201) |> json(item)
    end
  end

  def delete(conn, %{"id" => id_str}) do
    case Integer.parse(id_str) do
      {id, ""} ->
        Tracer.with_span "items.delete", %{attributes: [{"item.id", id}]} do
          ItemStore.delete(id)
          Logger.info("Item deleted", item_id: id)
          send_resp(conn, 204, "")
        end

      _ ->
        conn |> put_status(400) |> json(%{error: "Invalid item id", id: id_str})
    end
  end
end