defmodule Beacon.Loader.LayoutModuleLoader do
  @moduledoc false

  require Logger

  alias Beacon.Content
  alias Beacon.Loader

  def load_layout!(%Content.Layout{} = layout) do
    component_module = Loader.component_module_for_site(layout.site)
    module = Loader.layout_module_for_site(layout.id)
    render_function = render_layout(layout)
    ast = render(module, render_function, component_module)
    :ok = Loader.reload_module!(module, ast)
    :ok = Beacon.PubSub.layout_loaded(layout)
    {:ok, module, ast}
  end

  defp render(module_name, render_function, component_module) do
    quote do
      defmodule unquote(module_name) do
        use Phoenix.HTML
        import Phoenix.Component
        unquote(Loader.maybe_import_my_component(component_module, render_function))

        unquote(render_function)
      end
    end
  end

  defp render_layout(layout) do
    file = "site-#{layout.site}-layout-#{layout.title}"
    {:ok, ast} = Beacon.Template.HEEx.compile(layout.site, "", layout.template, file)

    quote do
      def render(var!(assigns)) when is_map(var!(assigns)) do
        unquote(ast)
      end

      def layout_assigns do
        %{
          title: unquote(layout.title),
          meta_tags: unquote(Macro.escape(layout.meta_tags)),
          resource_links: unquote(Macro.escape(layout.resource_links))
        }
      end
    end
  end
end
