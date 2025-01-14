# Liquex

A [Liquid](https://shopify.github.io/liquid/) template parser for Elixir.

Liquid template renderer for Elixir with 100% compatibility with the
[Liquid](https://shopify.github.io/liquid/) gem by [Shopify](https://www.shopify.com/).
If you find that this library is not byte for byte equivalent to liquid, please
[open an issue](https://github.com/markglenn/liquex/issues).

## Installation

The package is [available in Hex](https://hex.pm/packages/liquex) and can be installed
by adding `liquex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:liquex, "~> 0.10.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/liquex](https://hexdocs.pm/liquex).

## Basic Usage

```elixir
iex> {:ok, template_ast} = Liquex.parse("Hello {{ name }}!")
iex> {content, _context} = Liquex.render!(template_ast, %{"name" => "World"})

iex> content |> to_string()
"Hello World!"
```

## Migrating from 0.7 to 0.8

As of Liquex v0.8, the library has unified how tag code is created. If you made
any custom tags that did not follow the
[Custom Tags](https://hexdocs.pm/liquex/Liquex.html#module-custom-tags) format,
you will need to update them. That is because all tags now follow this standard.

## Supported features

Currently, all standard Liquid tags, filters, and types are fully supported
for liquid up to and include Liquid 5. Liquex can be considered a byte for byte
drop in replacement of the Liquid gem.

Starting with version 0.10.0, Liquex now supports the following features:

  * `{% render %}` tag
  * `{% liquid %}` tag

## Lazy variables

Liquex allows resolver functions for variables that may require some extra
work to generate. For example, Shopify has variables for things like
available products. Pulling all products every time would be too expensive
to do on every render. Instead, it would be better to lazily pull that
information as needed.

Instead of adding the product list to the context variable map, you can add
a function to the variable map. If a function is accessed in the variable
map, it is executed.

```elixir
products_resolver = fn _parent -> Product.all() end

with {:ok, document} <- Liquex.parse("There are {{ products.size }} products"),
    {result, _} <- Liquex.render!(document, %{products: products_resolver}) do
  result
end

"There are 5 products"
```

## Indifferent access

By default, Liquex accesses your maps and structs that may have atom or
string (or other type) keys. Liquex will try a string key first. If that
fails, it will fall back to using an atom keys.  This is similar to how
Ruby on Rails handles many of its hashes.

This allows you to pass in your structs without having to replace all your
keys with string keys.

```elixir
iex> {:ok, template_ast} = Liquex.parse("Hello {{ name }}!")
iex> {content, _context} = Liquex.render!(template_ast, %{name: "World"})
iex> content |> to_string()
"Hello World!"
```

## Caching

Liquex has a built in cache used specifically for the render tag currently. When
loading a partial/sub-template using the render tag, it will try pulling from
the cache associated with the context.

By default, caching is disabled, but you may use the built in ETS based cache by
configuring it in your context.

```elixir
:ok = Liquex.Cache.SimpleCache.init()
context = Context.new(%{...}, cache: Liquex.Cache.SimpleCache)
```

The simple cache is by definition quite simple. To use a more complete caching
system, such as [Cachex](https://github.com/whitfin/cachex), you can create a
module that implements the `Liquex.Cache` behaviour.

The cache system is very early on. It is expected that it will also be used to
memoize some of the variables within your context.

## Custom filters

Liquex contains the full suite of standard Liquid filters, but you may find that there are still
filters that you may want to add.

Liquex supports adding your own custom filters to the render pipeline.  When creating the context
for the renderer, set the filter module to your own module.

```elixir
defmodule CustomFilter do
  # Import all the standard liquid filters
  use Liquex.Filter

  def scream(value, _), do: String.upcase(value) <> "!"
end

context = Liquex.Context.new(%{}, filter_module: CustomFilter)
{:ok, template_ast} = Liquex.parse("{{'Hello World' | scream}}"

{result, _} = Liquex.render!(template_ast, context)
result |> to_string()

iex> "HELLO WORLD!"
```

## Custom tags

One of the strong points for Liquex is that the tag parser can be extended to support non-standard
tags. For example, Liquid used internally for the Shopify site includes a large range of tags that
are not supported by the base Ruby gem.  These tags could also be added to Liquex by extending the
liquid parser.

```elixir
defmodule CustomTag do
  @moduledoc false

  @behaviour Liquex.Tag

  import NimbleParsec

  @impl true
  # Parse <<Custom Tag>>
  def parse() do
    text =
      lookahead_not(string(">>"))
      |> utf8_char([])
      |> times(min: 1)
      |> reduce({Kernel, :to_string, []})
      |> tag(:text)

    ignore(string("<<"))
    |> optional(text)
    |> ignore(string(">>"))
  end

  @impl true
  def render(contents, context) do
    {result, context} = Liquex.render!(contents, context)
    {["Custom Tag: ", result], context}
  end
end

defmodule CustomParser do
  use Liquex.Parser, tags: [CustomTag]
end

iex> document = Liquex.parse!("<<Hello World!>>", CustomParser)
iex> {result, _} = Liquex.render!(document, context)
iex> result |> to_string()
"Custom Tag: Hello World!"
```

## Deviations from original Liquid gem

### Whitespace is kept in empty blocks

For performance reasons, whitespace is kept within empty blocks such as
for/if/unless. The liquid gem checks for "blank" renders and throws them away.
Instead, we continue to use IO lists to combine the output and don't check for
blank results to avoid too many conversions to strings.  Since Liquid is mostly
used for whitespace agnostic documents, this seemed like a decent tradeoff. If
you need better whitespace control, use `{%-`, `{{-`, `-%}`, and `-}}`.
