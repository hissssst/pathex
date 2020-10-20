# Common usage

Common usage of `Pathex` boils down to getters/setters for structures with defined set of fields

## GenServer state access

For example, you have a wallet of user and you want to have a quick access to amount of currencies user has,

State looks like:

```elixir
state = %{
  user_data: %{
    name: "...",
    private: %{
      wallet: %{
        "USD" => 123,
        "EUR" => 456
      }
    }
  }
}
```

And getter for currency amount will look like:

```elixir
def curreny(cur) do
  path :user_data / :private / :wallet / cur, :map
end
```

With this you can set, get and update value in state and it's better than
`put_in`, `update_in` because it's

* [Faster](https://github.com/hissssst/pathex_bench)
* You don't have to ensure that given field exsists when putting value

  Before:
  ```elixir
  case state do
    %{user_data: %{private: %{wallet: %{^cur => _}}}} ->
      put_in ..., amount
    %{user_data: %{private: %{wallet: %{}}}} ->
      put_in ..., %{cur => amount}
    ...
  end
  ```

  After:
  ```elixir
  Pathex.force_set(state, currency(cur), amount)
  ```

## Polymorphic input

Sometimes you don't know if incoming structure will be `Map` or `Keyword`
Pathex solves this problem by providing polymorphic input matching

```elixir
# For Keyword
{:ok, 1} =
  [x: 1]
  |> Pathex.view(path :x)

# For Map
{:ok, 1} =
  %{x: 1}
  |> Pathex.view(path :x)
```
