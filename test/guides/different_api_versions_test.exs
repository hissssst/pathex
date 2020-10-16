defmodule DifferentApiVersionsTest do

  use ExUnit.Case

  defmodule User do

    require Pathex
    import Pathex, only: [path: 1, path: 2]

    defstruct [
      id: 1,
      name: "Username1",
      phone: "123",
      address: %{
        street: "1st ave",
        house: "7/a"
      }
    ]

    def attrlens(attr) when attr in ~w[street house]a do
      path(:address / attr, :map)
    end
    def attrlens(attr), do: path(attr, :map)

  end

  defmodule ApiView do

    require Pathex
    import Pathex, only: [path: 1, path: 2, "~>": 2]

    @attrs ~w[id name phone street house]a

    def public_attributes, do: @attrs

    def users_to_model(users, version) do
      Enum.reduce(users, empty_model(version), & add_user(&1, &2, version))
    end

    def add_user(%User{} = user, model, ver) do
      Enum.reduce(@attrs, model, fn attr, model ->
        modell = userlens(ver, user.id, model) ~> attrlens(ver, attr)
        with(
          {:ok, value} <- Pathex.view(user, User.attrlens(attr)),
          {:ok, model} <- Pathex.force_set(model, modell, value)
        ) do
          model
        else
          _ -> model
        end
      end)
    end

    def empty_model(:v1), do: []
    def empty_model(:v2), do: %{}

    def userlens(:v1, id, model) do
      index = Enum.find_index(model, & match?(%{id: ^id}, &1)) || -1
      path index
    end
    def userlens(:v2, id, _) do
      path id, :map
    end

    def attrlens(:v1, attr) when attr in ~w[id name]a do
      path attr, :map
    end
    def attrlens(:v1, attr) when attr in ~w[street house]a do
      path :personal_data / :address / attr, :map
    end
    def attrlens(:v1, attr) do
      path :personal_data / attr, :map
    end
    def attrlens(:v2, attr) do
      path attr, :map
    end

    def modelitemlens(:v1), do: Pathex.Lenses.id()
    def modelitemlens(:v2), do: path(1)

  end

  test "version 1" do
    received =
      [%User{}, %User{id: 2}]
      |> ApiView.users_to_model(:v1)
      |> Enum.sort()

    must_be = [
      %{
        id: 1,
        name: "Username1",
        personal_data: %{
          phone: "123",
          address: %{street: "1st ave", house:  "7/a"}
        }
      },
      %{
        id: 2,
        name: "Username1",
        personal_data: %{
          phone: "123",
          address: %{street: "1st ave", house:  "7/a"}
        }
      }
    ]

    assert received == must_be
  end

  test "version 2" do
    received = ApiView.users_to_model([%User{}, %User{id: 2}], :v2)

    must_be = %{
      1 => %{
        id: 1,
        name: "Username1",
        phone: "123",
        street: "1st ave",
        house:  "7/a"
      },
      2 => %{
        id: 2,
        name: "Username1",
        phone: "123",
        street: "1st ave",
        house:  "7/a"
      }
    }

    assert received == must_be
  end

  defmodule StructuresToAggregatableView do

    require Pathex
    import Pathex, only: [path: 1, path: 2, "~>": 2]

    def to_model(users, ver, %{
      attrs:         attrs,
      userattrl:     userattrl,
      userl:         userl,
      modelattrl:    modelattrl,
      initial_model: model
    }) do
      for user <- users, attr <- attrs, reduce: model.(ver) do
        model ->
          modell = userl.(ver, user.id, model) ~> modelattrl.(ver, attr)
          with(
            {:ok, value} <- Pathex.view(user, userattrl.(attr)),
            {:ok, model} <- Pathex.force_set(model, modell, value)
          ) do
            model
          else
            _ -> model
          end
      end
    end

    def to_users(model, ver, %{
      attrs:      attrs,
      userattrl:  userattrl,
      modelattrl: modelattrl,
      modeliteml: modeliteml
    }) do
      for item <- model, into: [] do
        for attr <- attrs, reduce: %{} do
          user ->
            with(
              {:ok, value} <- Pathex.view(item, modeliteml.(ver) ~> modelattrl.(ver, attr)),
              {:ok, user}  <- Pathex.force_set(user, userattrl.(attr), value)
            ) do
              user
            else
              _ ->
                user
            end
        end
      end
    end
  end

  test "forward-backward" do
    configuration = %{
      attrs:         ApiView.public_attributes(),
      userattrl:     &User.attrlens/1,
      userl:         &ApiView.userlens/3,
      modelattrl:    &ApiView.attrlens/2,
      modeliteml:    &ApiView.modelitemlens/1,
      initial_model: &ApiView.empty_model/1
    }

    users = [%User{}, %User{id: 2}]

    model = [
      %{
        id: 1,
        name: "Username1",
        personal_data: %{
          phone: "123",
          address: %{street: "1st ave", house:  "7/a"}
        }
      },
      %{
        id: 2,
        name: "Username1",
        personal_data: %{
          phone: "123",
          address: %{street: "1st ave", house:  "7/a"}
        }
      }
    ]

    assert (
      users
      |> StructuresToAggregatableView.to_model(:v1, configuration)
      |> Enum.sort()
    ) == model

    assert (
      model
      |> StructuresToAggregatableView.to_users(:v1, configuration)
      |> Enum.sort()
    ) == (
      users
      |> Enum.map(&Map.from_struct/1)
    )

    model = %{
      1 => %{
        id: 1,
        name: "Username1",
        phone: "123",
        street: "1st ave",
        house:  "7/a"
      },
      2 => %{
        id: 2,
        name: "Username1",
        phone: "123",
        street: "1st ave",
        house:  "7/a"
      }
    }

    assert StructuresToAggregatableView.to_model(users, :v2, configuration) == model

    assert (
      model
      |> StructuresToAggregatableView.to_users(:v2, configuration)
      |> Enum.sort()
    ) == (
      users
      |> Enum.map(&Map.from_struct/1)
    )
  end

  defmodule AggrToAggr do

    require Pathex

    def convert(from, %{
      froml:   froml,
      tol:     tol,
      initial: initial,
      inner:   inner,
      keys:    keys
    }) do
      for item <- from, into: initial do
        for key <- keys, reduce: inner do
          acc ->
            with(
              {:ok, value} <- Pathex.view(item, froml.(key)),
              {:ok, acc}  <- Pathex.force_set(acc, tol.(key), value)
            ) do
              acc
            else
              _ -> acc
            end
        end
      end
    end

  end

  test "abstract solution" do
    require Pathex
    import Pathex, only: [path: 1, path: 2, &&&: 2]
    userl = fn
      key when key in ~w[street house]a -> path :address / key, :map
      key -> path key, :map
    end
    modell = fn
      :id -> path(0) &&& path(1 / :id)
      key -> path(1 / key)
    end

    users = [%User{}, %User{id: 2}]

    result =
      AggrToAggr.convert(users, %{
        froml:   userl,
        tol:     modell,
        initial: %{},
        inner:   {0, %{}},
        keys:    ~w[id name phone street house]a
      })

    model = %{
      1 => %{
        id: 1,
        name: "Username1",
        phone: "123",
        street: "1st ave",
        house:  "7/a"
      },
      2 => %{
        id: 2,
        name: "Username1",
        phone: "123",
        street: "1st ave",
        house:  "7/a"
      }
    }

    assert result == model

    result =
      AggrToAggr.convert(model, %{
        froml:   modell,
        tol:     userl,
        initial: [],
        inner:   %User{},
        keys:    ~w[id name phone street house]a
      })

    assert Enum.sort(result) == users
  end

end
