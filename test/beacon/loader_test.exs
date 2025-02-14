defmodule Beacon.LoaderTest do
  use BeaconWeb.ConnCase, async: false

  import Beacon.Fixtures
  alias Beacon.Content
  alias Beacon.Loader

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  test "reload_module! validates ast" do
    ast =
      quote do
        defmodule Foo.Bar do
          def
        end
      end

    assert_raise Beacon.LoaderError, ~r/failed to load module Foo.Bar/, fn ->
      Loader.reload_module!(Foo.Bar, ast, "custom file")
    end
  end

  describe "page loading" do
    defp create_page(_) do
      stylesheet_fixture()

      layout =
        published_layout_fixture(
          template: """
          <header>layout_v1</header>
          <%= @inner_content %>
          """
        )

      component =
        component_fixture(
          name: "component_loader_test",
          body: """
          <header>component_v1</header>
          """
        )

      page =
        published_page_fixture(
          layout_id: layout.id,
          path: "/loader_test",
          template: """
          <main>
            <div>page_v1</div>
            <%= my_component("component_loader_test", %{}) %>
          </main>
          """
        )

      Beacon.Loader.load_page(page)

      [layout: layout, page: page, component: component]
    end

    setup [:create_page]

    test "load page and dependencies", %{conn: conn, layout: layout, page: page, component: component} do
      {:ok, _view, html} = live(conn, "/loader_test")
      assert html =~ "component_v1"
      assert html =~ "layout_v1"
      assert html =~ "page_v1"

      Content.update_component(component, %{body: "<header>component_v2</header>"})

      {:ok, layout} =
        Content.update_layout(layout, %{
          template: """
          <header>layout_v2</header>
          <%= @inner_content %>
          """
        })

      Content.publish_layout(layout)

      Content.update_layout(layout, %{
        template: """
        <header>layout_v3_unpublished</header>
        <%= @inner_content %>
        """
      })

      {:ok, page} =
        Content.update_page(page, %{
          template: """
          <main>
            <div>page_v2</div>
            <%= my_component("component_loader_test", %{}) %>
          </main>
          """
        })

      {:ok, page} = Content.publish_page(page)

      Beacon.Loader.load_page(page)

      {:ok, _view, html} = live(conn, "/loader_test")
      assert html =~ "component_v2"
      assert html =~ "layout_v2"
      assert html =~ "page_v2"
    end

    test "unload page", %{page: page} do
      module = Beacon.Loader.page_module_for_site(page.id)
      assert Keyword.has_key?(module.__info__(:functions), :page_assigns)

      Beacon.Loader.unload_page(page)

      refute :erlang.module_loaded(module)
    end
  end
end
