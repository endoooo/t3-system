defmodule T3System.RegistrationsTest do
  use T3System.DataCase

  alias T3System.Accounts.Scope
  alias T3System.Registrations
  alias T3System.Registrations.Registration
  alias T3System.Registrations.RegistrationPlayer

  import T3System.Factory

  describe "registrations" do
    test "list_registrations/0 returns all registrations with preloads" do
      registration = insert(:registration)
      [result] = Registrations.list_registrations()
      assert result.id == registration.id

      assert [%{player: %T3System.Players.Player{}, club: %T3System.Clubs.Club{}}] =
               result.registration_players

      assert %T3System.Events.Event{} = result.event
    end

    test "get_registration!/1 returns the registration with given id" do
      registration = insert(:registration)
      result = Registrations.get_registration!(registration.id)
      assert result.id == registration.id

      assert [%{player: %T3System.Players.Player{}, club: %T3System.Clubs.Club{}}] =
               result.registration_players

      assert %T3System.Events.Event{} = result.event
    end

    test "get_registration!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn -> Registrations.get_registration!(0) end
    end

    test "create_registration/2 with nested players creates a registration" do
      scope = Scope.for_user(insert(:superuser))
      player = insert(:player)
      event = insert(:event)
      club = insert(:club)
      category = insert(:category)

      valid_attrs = %{
        event_id: event.id,
        category_id: category.id,
        registration_players: [%{player_id: player.id, club_id: club.id, position: 1}]
      }

      assert {:ok, %Registration{} = registration} =
               Registrations.create_registration(scope, valid_attrs)

      registration = Registrations.get_registration!(registration.id)
      assert registration.event_id == event.id
      assert registration.category_id == category.id

      assert [%{player: %{id: player_id}, club: %{id: club_id}}] =
               registration.registration_players

      assert {player_id, club_id} == {player.id, club.id}
    end

    test "create_registration/2 without players returns error changeset" do
      scope = Scope.for_user(insert(:superuser))

      assert {:error, changeset} =
               Registrations.create_registration(scope, %{
                 event_id: insert(:event).id,
                 category_id: insert(:category).id,
                 registration_players: []
               })

      assert %{registration_players: [_]} = errors_on(changeset)
    end

    test "create_registration/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      assert {:error, %Ecto.Changeset{}} = Registrations.create_registration(scope, %{})
    end

    test "create_registration/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      player = insert(:player)
      event = insert(:event)
      club = insert(:club)

      assert_raise FunctionClauseError, fn ->
        Registrations.create_registration(scope, %{
          event_id: event.id,
          registration_players: [%{player_id: player.id, club_id: club.id, position: 1}]
        })
      end
    end

    test "create_registration/2 rejects a player already registered in the event + category" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)
      [taken] = registration.registration_players

      attrs = %{
        event_id: registration.event_id,
        category_id: registration.category_id,
        registration_players: [
          %{player_id: taken.player_id, club_id: insert(:club).id, position: 1}
        ]
      }

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)

      assert %{registration_players: [%{player_id: ["already registered in this category"]}]} =
               errors_on(changeset)
    end

    test "create_registration/2 rejects a player already in position 2 of another registration" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      category = insert(:category)
      partner = insert(:player)

      insert(:registration,
        event: event,
        category: category,
        registration_players: [
          build(:registration_player, position: 1),
          build(:registration_player, player: partner, position: 2)
        ]
      )

      attrs = %{
        event_id: event.id,
        category_id: category.id,
        registration_players: [%{player_id: partner.id, club_id: insert(:club).id, position: 1}]
      }

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)

      assert %{registration_players: [%{player_id: ["already registered in this category"]}]} =
               errors_on(changeset)
    end

    test "create_registration/2 accepts the same player in another category of the event" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)
      [taken] = registration.registration_players

      attrs = %{
        event_id: registration.event_id,
        category_id: insert(:category).id,
        registration_players: [%{player_id: taken.player_id, club_id: taken.club_id, position: 1}]
      }

      assert {:ok, %Registration{}} = Registrations.create_registration(scope, attrs)
    end

    test "create_registration/2 rejects a player count that doesn't match the format" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      singles = insert(:category)
      doubles = insert(:category, format: "doubles")

      rows = fn count, max_position ->
        # Positions stay within the format's range so only the player count is wrong.
        for position <- 1..count//1 do
          %{
            player_id: insert(:player).id,
            club_id: insert(:club).id,
            position: min(position, max_position)
          }
        end
      end

      attrs = fn category, count ->
        max_position = if category.format == "doubles", do: 2, else: 1

        %{
          event_id: event.id,
          category_id: category.id,
          registration_players: rows.(count, max_position)
        }
      end

      assert {:error, changeset} = Registrations.create_registration(scope, attrs.(singles, 0))
      assert %{registration_players: [_ | _]} = errors_on(changeset)

      assert {:error, changeset} = Registrations.create_registration(scope, attrs.(singles, 2))

      assert %{registration_players: ["a singles registration must have exactly 1 player"]} =
               errors_on(changeset)

      assert {:error, changeset} = Registrations.create_registration(scope, attrs.(doubles, 1))

      assert %{registration_players: ["a doubles registration must have exactly 2 players"]} =
               errors_on(changeset)

      assert {:error, changeset} = Registrations.create_registration(scope, attrs.(doubles, 3))

      assert %{registration_players: ["a doubles registration must have exactly 2 players"]} =
               errors_on(changeset)

      assert {:ok, %Registration{}} = Registrations.create_registration(scope, attrs.(doubles, 2))
    end

    test "create_registration/2 rejects the same player twice in one pair" do
      scope = Scope.for_user(insert(:superuser))
      player = insert(:player)

      attrs = %{
        event_id: insert(:event).id,
        category_id: insert(:category, format: "doubles").id,
        registration_players: [
          %{player_id: player.id, club_id: insert(:club).id, position: 1},
          %{player_id: player.id, club_id: insert(:club).id, position: 2}
        ]
      }

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)

      assert %{registration_players: ["a pair must have two different players"]} =
               errors_on(changeset)
    end

    test "create_registration/2 rejects a partner already in another pair of the category" do
      scope = Scope.for_user(insert(:superuser))
      existing = insert(:doubles_registration)
      [_, partner] = existing.registration_players

      attrs = %{
        event_id: existing.event_id,
        category_id: existing.category_id,
        registration_players: [
          %{player_id: insert(:player).id, club_id: insert(:club).id, position: 1},
          %{player_id: partner.player_id, club_id: insert(:club).id, position: 2}
        ]
      }

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)

      assert %{registration_players: [%{}, %{player_id: ["already registered in this category"]}]} =
               errors_on(changeset)
    end

    test "create_registration/2 accepts a singles player in a doubles category of the event" do
      scope = Scope.for_user(insert(:superuser))
      singles = insert(:registration)
      [rp] = singles.registration_players

      attrs = %{
        event_id: singles.event_id,
        category_id: insert(:category, format: "doubles").id,
        registration_players: [
          %{player_id: rp.player_id, club_id: rp.club_id, position: 1},
          %{player_id: insert(:player).id, club_id: insert(:club).id, position: 2}
        ]
      }

      assert {:ok, %Registration{}} = Registrations.create_registration(scope, attrs)
    end

    test "update_registration/3 replaces the players" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)
      new_player = insert(:player)
      new_club = insert(:club)

      assert {:ok, %Registration{}} =
               Registrations.update_registration(scope, registration, %{
                 registration_players: [
                   %{player_id: new_player.id, club_id: new_club.id, position: 1}
                 ]
               })

      assert [%{player_id: player_id, club_id: club_id}] =
               Registrations.get_registration!(registration.id).registration_players

      assert {player_id, club_id} == {new_player.id, new_club.id}
    end

    test "update_registration/3 swaps the positions of a pair" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:doubles_registration)
      [rp1, rp2] = registration.registration_players

      assert {:ok, %Registration{}} =
               Registrations.update_registration(scope, registration, %{
                 registration_players: [
                   %{id: rp1.id, player_id: rp1.player_id, club_id: rp1.club_id, position: 2},
                   %{id: rp2.id, player_id: rp2.player_id, club_id: rp2.club_id, position: 1}
                 ]
               })

      assert [rp2.player_id, rp1.player_id] ==
               Enum.map(
                 Registrations.get_registration!(registration.id).registration_players,
                 & &1.player_id
               )
    end

    test "update_registration/3 swaps the players between the rows of a pair" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:doubles_registration)
      [rp1, rp2] = registration.registration_players

      assert {:ok, %Registration{}} =
               Registrations.update_registration(scope, registration, %{
                 "registration_players" => %{
                   "0" => %{
                     "id" => to_string(rp1.id),
                     "player_id" => to_string(rp2.player_id),
                     "club_id" => to_string(rp2.club_id),
                     "position" => "1"
                   },
                   "1" => %{
                     "id" => to_string(rp2.id),
                     "player_id" => to_string(rp1.player_id),
                     "club_id" => to_string(rp1.club_id),
                     "position" => "2"
                   }
                 }
               })

      assert [{rp2.player_id, rp2.club_id}, {rp1.player_id, rp1.club_id}] ==
               Enum.map(
                 Registrations.get_registration!(registration.id).registration_players,
                 &{&1.player_id, &1.club_id}
               )
    end

    test "update_registration/3 substitutes a partner and changes a club" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:doubles_registration)
      [rp1, rp2] = registration.registration_players
      substitute = insert(:player)
      new_club = insert(:club)

      assert {:ok, %Registration{}} =
               Registrations.update_registration(scope, registration, %{
                 registration_players: [
                   %{id: rp1.id, player_id: rp1.player_id, club_id: new_club.id, position: 1},
                   %{id: rp2.id, player_id: substitute.id, club_id: rp2.club_id, position: 2}
                 ]
               })

      assert [{rp1.player_id, new_club.id}, {substitute.id, rp2.club_id}] ==
               Enum.map(
                 Registrations.get_registration!(registration.id).registration_players,
                 &{&1.player_id, &1.club_id}
               )
    end

    test "update_registration/3 rejects a substitute already in another pair" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:doubles_registration)
      [rp1, rp2] = registration.registration_players

      other =
        insert(:doubles_registration,
          event: registration.event,
          category: registration.category
        )

      [taken, _] = other.registration_players

      assert {:error, changeset} =
               Registrations.update_registration(scope, registration, %{
                 registration_players: [
                   %{id: rp1.id, player_id: rp1.player_id, club_id: rp1.club_id, position: 1},
                   %{id: rp2.id, player_id: taken.player_id, club_id: rp2.club_id, position: 2}
                 ]
               })

      assert %{registration_players: [%{}, %{player_id: ["already registered in this category"]}]} =
               errors_on(changeset)
    end

    test "update_registration/3 rejects the same player twice in a pair" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:doubles_registration)
      [rp1, rp2] = registration.registration_players

      assert {:error, changeset} =
               Registrations.update_registration(scope, registration, %{
                 registration_players: [
                   %{id: rp1.id, player_id: rp1.player_id, club_id: rp1.club_id, position: 1},
                   %{id: rp2.id, player_id: rp1.player_id, club_id: rp2.club_id, position: 2}
                 ]
               })

      assert %{registration_players: ["a pair must have two different players"]} =
               errors_on(changeset)
    end

    test "update_registration/3 keeps matches, groups and final standing with the pair" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:doubles_registration, final_standing: 1)
      [rp1, rp2] = registration.registration_players
      opponent = insert(:doubles_registration, event: registration.event)
      group = insert(:group)
      T3System.Matches.add_registration_to_group(scope, group.id, registration.id)

      match =
        insert(:match,
          event: registration.event,
          group: group,
          registration1_id: registration.id,
          registration2_id: opponent.id,
          winner_registration_id: registration.id
        )

      insert(:match_set, match: match, winner_registration_id: registration.id)

      assert {:ok, %Registration{}} =
               Registrations.update_registration(scope, registration, %{
                 registration_players: [
                   %{id: rp1.id, player_id: rp1.player_id, club_id: rp1.club_id, position: 1},
                   %{id: rp2.id, player_id: insert(:player).id, club_id: rp2.club_id, position: 2}
                 ]
               })

      updated =
        Registrations.get_registration!(registration.id)
        |> Repo.preload([:groups, :matches_as_registration1])

      assert updated.final_standing == 1
      assert [%{id: group_id}] = updated.groups
      assert group_id == group.id

      assert [%{id: match_id, winner_registration_id: winner_id}] =
               updated.matches_as_registration1

      assert {match_id, winner_id} == {match.id, registration.id}

      assert [%{winner_registration_id: ^winner_id}] =
               Repo.preload(Repo.get!(T3System.Matches.Match, match.id), :sets).sets
    end

    test "update_registration/3 moving to a category where the player is taken is rejected" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)
      [rp] = registration.registration_players

      other =
        insert(:registration,
          event: registration.event,
          registration_players: [build(:registration_player, player: rp.player)]
        )

      assert {:error, changeset} =
               Registrations.update_registration(scope, registration, %{
                 category_id: other.category_id
               })

      assert %{category_id: ["player already registered in this category"]} =
               errors_on(changeset)
    end

    test "update_registration/3 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)

      assert {:error, %Ecto.Changeset{}} =
               Registrations.update_registration(scope, registration, %{registration_players: []})
    end

    test "list_registered_player_ids/2 returns players in any position" do
      event = insert(:event)
      category = insert(:category)
      [first, partner] = insert_list(2, :player)

      insert(:registration,
        event: event,
        category: category,
        registration_players: [
          build(:registration_player, player: first, position: 1),
          build(:registration_player, player: partner, position: 2)
        ]
      )

      insert(:registration, event: event)

      assert Registrations.list_registered_player_ids(event.id, category.id) ==
               MapSet.new([first.id, partner.id])
    end

    test "update_registration/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      registration = insert(:registration)

      assert_raise FunctionClauseError, fn ->
        Registrations.update_registration(scope, registration, %{})
      end
    end

    test "delete_registration/2 deletes the registration" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)
      assert {:ok, %Registration{}} = Registrations.delete_registration(scope, registration)
      assert_raise Ecto.NoResultsError, fn -> Registrations.get_registration!(registration.id) end
    end

    test "delete_registration/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      registration = insert(:registration)

      assert_raise FunctionClauseError, fn ->
        Registrations.delete_registration(scope, registration)
      end
    end

    test "change_registration/1 returns a registration changeset" do
      registration = insert(:registration)
      assert %Ecto.Changeset{} = Registrations.change_registration(registration)
    end

    test "create_registration/2 rejects a player position other than 1 or 2" do
      scope = Scope.for_user(insert(:superuser))
      category = insert(:category)

      attrs = %{
        event_id: insert(:event).id,
        category_id: category.id,
        registration_players: [
          %{player_id: insert(:player).id, club_id: insert(:club).id, position: 3}
        ]
      }

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)
      assert %{registration_players: [%{position: ["is invalid"]}]} = errors_on(changeset)
    end

    test "the database rejects a player position below 1" do
      registration = insert(:registration)

      changeset =
        %RegistrationPlayer{registration_id: registration.id}
        |> RegistrationPlayer.changeset(%{
          player_id: insert(:player).id,
          club_id: insert(:club).id,
          position: 2
        })
        |> Ecto.Changeset.force_change(:position, 0)

      assert {:error, changeset} = T3System.Repo.insert(changeset)
      assert %{position: ["must be at least 1"]} = errors_on(changeset)
    end

    test "create_registration/2 rejects a third position in a doubles category" do
      scope = Scope.for_user(insert(:superuser))

      attrs = %{
        event_id: insert(:event).id,
        category_id: insert(:category, format: "doubles").id,
        registration_players: [
          %{player_id: insert(:player).id, club_id: insert(:club).id, position: 1},
          %{player_id: insert(:player).id, club_id: insert(:club).id, position: 3}
        ]
      }

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)
      assert %{registration_players: [%{}, %{position: ["is invalid"]}]} = errors_on(changeset)
    end
  end

  describe "teams" do
    setup do
      %{scope: Scope.for_user(insert(:superuser)), event: insert(:event)}
    end

    defp team_rows(count) do
      for position <- 1..count//1 do
        %{player_id: insert(:player).id, club_id: insert(:club).id, position: position}
      end
    end

    defp team_attrs(event, category, attrs) do
      Map.merge(%{event_id: event.id, category_id: category.id}, attrs)
    end

    test "create_registration/2 accepts a named team of any size", %{scope: scope, event: event} do
      category = insert(:team_category)

      for count <- [1, 5] do
        attrs =
          team_attrs(event, category, %{
            name: "Team #{count}",
            registration_players: team_rows(count)
          })

        assert {:ok, %Registration{} = team} = Registrations.create_registration(scope, attrs)
        assert length(Registrations.get_registration!(team.id).registration_players) == count
        assert team.name == "Team #{count}"
      end
    end

    test "create_registration/2 requires a team name", %{scope: scope, event: event} do
      attrs = team_attrs(event, insert(:team_category), %{registration_players: team_rows(3)})

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_registration/2 requires at least one team player", %{scope: scope, event: event} do
      attrs = team_attrs(event, insert(:team_category), %{name: "AABB", registration_players: []})

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)
      assert %{registration_players: [_ | _]} = errors_on(changeset)
    end

    test "create_registration/2 rejects the same player twice in a team", %{
      scope: scope,
      event: event
    } do
      player = insert(:player)

      rows = [
        %{player_id: player.id, club_id: insert(:club).id, position: 1},
        %{player_id: insert(:player).id, club_id: insert(:club).id, position: 2},
        %{player_id: player.id, club_id: insert(:club).id, position: 3}
      ]

      attrs =
        team_attrs(event, insert(:team_category), %{name: "AABB", registration_players: rows})

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)

      assert %{registration_players: ["a team can't have the same player twice"]} =
               errors_on(changeset)
    end

    test "create_registration/2 rejects a player already in another team of the category", %{
      scope: scope
    } do
      existing = insert(:team)
      [_, taken | _] = existing.registration_players

      rows = [
        %{player_id: insert(:player).id, club_id: insert(:club).id, position: 1},
        %{player_id: taken.player_id, club_id: insert(:club).id, position: 2}
      ]

      attrs = %{
        event_id: existing.event_id,
        category_id: existing.category_id,
        name: "Other",
        registration_players: rows
      }

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)

      assert %{registration_players: [%{}, %{player_id: ["already registered in this category"]}]} =
               errors_on(changeset)
    end

    test "create_registration/2 rejects a name outside team categories", %{
      scope: scope,
      event: event
    } do
      for {category, count} <- [{insert(:category), 1}, {insert(:category, format: "doubles"), 2}] do
        attrs =
          team_attrs(event, category, %{name: "AABB", registration_players: team_rows(count)})

        assert {:error, changeset} = Registrations.create_registration(scope, attrs)
        assert %{name: ["must be blank outside team categories"]} = errors_on(changeset)
      end
    end

    test "update_registration/3 renames a team and adds a player", %{scope: scope} do
      team = insert(:team)
      new_player = insert(:player)

      rows =
        Enum.map(team.registration_players, &Map.take(&1, [:player_id, :club_id, :position])) ++
          [%{player_id: new_player.id, club_id: insert(:club).id, position: 4}]

      assert {:ok, %Registration{}} =
               Registrations.update_registration(scope, team, %{
                 name: "Renamed",
                 registration_players: rows
               })

      updated = Registrations.get_registration!(team.id)
      assert updated.name == "Renamed"
      assert List.last(updated.registration_players).player_id == new_player.id
      assert length(updated.registration_players) == 4
    end
  end
end
