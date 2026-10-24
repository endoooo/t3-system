defmodule T3System.MatchesTest do
  use T3System.DataCase

  alias T3System.Accounts.Scope
  alias T3System.Events
  alias T3System.Matches
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.MatchSet
  alias T3System.Matches.Stage

  import T3System.Factory

  # ---------------------------------------------------------------------------
  # Stages
  # ---------------------------------------------------------------------------

  describe "stages" do
    test "list_stages_for_event/1 returns stages ordered by order" do
      event = insert(:event)
      category = insert(:category)
      s2 = insert(:stage, event: event, category: category, order: 2, name: "Knockout")
      s1 = insert(:stage, event: event, category: category, order: 1, name: "Groups")
      _other = insert(:stage)

      results = Matches.list_stages_for_event(event.id)
      assert length(results) == 2
      assert [first, second] = results
      assert first.id == s1.id
      assert second.id == s2.id
    end

    test "create_stage/2 with valid data creates a group stage" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      category = insert(:category)

      assert {:ok, %Stage{} = stage} =
               Matches.create_stage(scope, %{
                 name: "Groups",
                 type: "group",
                 order: 1,
                 event_id: event.id,
                 category_id: category.id
               })

      assert stage.name == "Groups"
      assert stage.type == "group"
      assert stage.order == 1
      assert stage.rounds == nil
    end

    test "create_stage/2 with bracket type and rounds creates stage with matches" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      category = insert(:category)

      assert {:ok, %Stage{} = stage} =
               Matches.create_stage(scope, %{
                 name: "Knockout",
                 type: "bracket",
                 order: 1,
                 rounds: 2,
                 event_id: event.id,
                 category_id: category.id
               })

      assert stage.type == "bracket"
      assert stage.rounds == 2

      # 2^2 - 1 = 3 matches
      matches = Matches.list_matches_for_event(event.id)
      assert length(matches) == 3
      assert Enum.all?(matches, &(&1.stage_id == stage.id))
    end

    test "create_stage/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))

      assert_raise FunctionClauseError, fn ->
        Matches.create_stage(scope, %{name: "Groups", order: 1})
      end
    end

    test "delete_stage/2 deletes the stage" do
      scope = Scope.for_user(insert(:superuser))
      stage = insert(:stage)
      assert {:ok, %Stage{}} = Matches.delete_stage(scope, stage)
      assert_raise Ecto.NoResultsError, fn -> Matches.get_stage!(stage.id) end
    end

    test "reconfigure_stage_bracket/3 regenerates bracket matches" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      category = insert(:category)

      {:ok, stage} =
        Matches.create_stage(scope, %{
          name: "Knockout",
          type: "bracket",
          order: 1,
          rounds: 2,
          event_id: event.id,
          category_id: category.id
        })

      # Initially 3 matches (2 rounds)
      assert length(Matches.list_matches_for_event(event.id)) == 3

      # Reconfigure to 3 rounds → 7 matches
      {:ok, updated} = Matches.reconfigure_stage_bracket(scope, stage, 3)
      assert updated.rounds == 3
      assert length(Matches.list_matches_for_event(event.id)) == 7
    end

    test "reconfigure_stage_bracket/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      stage = insert(:stage, type: "bracket", rounds: 2)

      assert_raise FunctionClauseError, fn ->
        Matches.reconfigure_stage_bracket(scope, stage, 3)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Groups
  # ---------------------------------------------------------------------------

  describe "groups" do
    test "list_groups_for_event/1 returns groups for the event" do
      group = insert(:group)
      _other_group = insert(:group)

      stage = T3System.Repo.preload(group, :stage).stage
      results = Matches.list_groups_for_event(stage.event_id)
      assert length(results) == 1
      assert hd(results).id == group.id
    end

    test "get_group!/1 returns the group with given id" do
      group = insert(:group)
      result = Matches.get_group!(group.id)
      assert result.id == group.id
    end

    test "get_group!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn -> Matches.get_group!(0) end
    end

    test "create_group/2 with valid data creates a group" do
      scope = Scope.for_user(insert(:superuser))
      stage = insert(:stage)

      assert {:ok, %Group{} = group} =
               Matches.create_group(scope, %{
                 name: "Group A",
                 stage_id: stage.id
               })

      assert group.name == "Group A"
      assert group.stage_id == stage.id
    end

    test "create_group/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      stage = insert(:stage, type: "group")

      assert {:error, %Ecto.Changeset{}} =
               Matches.create_group(scope, %{stage_id: stage.id})
    end

    test "create_group/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      stage = insert(:stage)

      assert_raise FunctionClauseError, fn ->
        Matches.create_group(scope, %{name: "Group A", stage_id: stage.id})
      end
    end

    test "create_group/2 on a bracket-type stage returns error" do
      scope = Scope.for_user(insert(:superuser))
      stage = insert(:stage, type: "bracket")

      assert {:error, :stage_type_mismatch} =
               Matches.create_group(scope, %{
                 name: "Group A",
                 stage_id: stage.id
               })
    end

    test "update_group/3 with valid data updates the group" do
      scope = Scope.for_user(insert(:superuser))
      group = insert(:group)

      assert {:ok, %Group{} = updated} = Matches.update_group(scope, group, %{name: "Group B"})
      assert updated.name == "Group B"
    end

    test "update_group/3 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      group = insert(:group)

      assert {:error, %Ecto.Changeset{}} = Matches.update_group(scope, group, %{name: nil})
    end

    test "update_group/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      group = insert(:group)

      assert_raise FunctionClauseError, fn ->
        Matches.update_group(scope, group, %{name: "Group B"})
      end
    end

    test "delete_group/2 deletes the group" do
      scope = Scope.for_user(insert(:superuser))
      group = insert(:group)
      assert {:ok, %Group{}} = Matches.delete_group(scope, group)
      assert_raise Ecto.NoResultsError, fn -> Matches.get_group!(group.id) end
    end

    test "delete_group/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      group = insert(:group)

      assert_raise FunctionClauseError, fn -> Matches.delete_group(scope, group) end
    end

    test "change_group/1 returns a group changeset" do
      group = insert(:group)
      assert %Ecto.Changeset{} = Matches.change_group(group)
    end
  end

  # ---------------------------------------------------------------------------
  # Matches
  # ---------------------------------------------------------------------------

  describe "matches" do
    test "list_matches_for_event/1 returns matches for the event with preloads" do
      match = insert(:match)
      _other_match = insert(:match)

      results = Matches.list_matches_for_event(match.event_id)
      assert length(results) == 1
      [result] = results
      assert result.id == match.id
      assert %Group{} = result.group
    end

    test "get_match!/1 returns the match with given id and preloads" do
      match = insert(:match)
      result = Matches.get_match!(match.id)
      assert result.id == match.id
      assert %Group{} = result.group
    end

    test "get_match!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(0) end
    end

    test "create_match/2 with group context creates a match" do
      scope = Scope.for_user(insert(:superuser))
      stage = insert(:stage)
      group = insert(:group, stage: stage)

      attrs = %{event_id: stage.event_id, group_id: group.id}

      assert {:ok, %Match{} = match} = Matches.create_match(scope, attrs)
      assert match.group_id == group.id
      assert match.event_id == stage.event_id
      assert match.stage_id == nil
    end

    test "create_match/2 with bracket stage context creates a match" do
      scope = Scope.for_user(insert(:superuser))
      stage = insert(:stage, type: "bracket", rounds: 2)

      attrs = %{event_id: stage.event_id, stage_id: stage.id, round: 1, position: 1}

      assert {:ok, %Match{} = match} = Matches.create_match(scope, attrs)
      assert match.stage_id == stage.id
      assert match.round == 1
      assert match.position == 1
      assert match.group_id == nil
    end

    test "scheduled_position defaults to 0" do
      scope = Scope.for_user(insert(:superuser))
      stage = insert(:stage)
      group = insert(:group, stage: stage)

      attrs = %{event_id: stage.event_id, group_id: group.id}
      assert {:ok, %Match{} = match} = Matches.create_match(scope, attrs)
      assert match.scheduled_position == 0
    end

    test "scheduled_position can be set via changeset" do
      scope = Scope.for_user(insert(:superuser))
      stage = insert(:stage)
      group = insert(:group, stage: stage)

      attrs = %{event_id: stage.event_id, group_id: group.id, scheduled_position: 5}
      assert {:ok, %Match{} = match} = Matches.create_match(scope, attrs)
      assert match.scheduled_position == 5
    end

    test "create_match/2 with participants creates a match" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      stage = insert(:stage, event: event)
      group = insert(:group, stage: stage)
      reg1 = insert(:registration, event: event)
      reg2 = insert(:registration, event: event)

      attrs = %{
        event_id: event.id,
        group_id: group.id,
        registration1_id: reg1.id,
        registration2_id: reg2.id,
        scheduled_at: ~U[2026-06-01 10:00:00Z]
      }

      assert {:ok, %Match{} = match} = Matches.create_match(scope, attrs)
      assert match.registration1_id == reg1.id
      assert match.registration2_id == reg2.id
      assert match.scheduled_at == ~U[2026-06-01 10:00:00Z]
    end

    test "create_match/2 without group or stage returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Matches.create_match(scope, %{event_id: event.id})

      assert %{base: [_]} = errors_on(changeset)
    end

    test "create_match/2 with both group and stage returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      category = insert(:category)
      group_stage = insert(:stage, event: event, category: category, type: "group", order: 1)
      bracket_stage = insert(:stage, event: event, category: category, type: "bracket", order: 2)
      group = insert(:group, stage: group_stage)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Matches.create_match(scope, %{
                 event_id: event.id,
                 group_id: group.id,
                 stage_id: bracket_stage.id
               })

      assert %{base: [_]} = errors_on(changeset)
    end

    test "create_match/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      assert {:error, %Ecto.Changeset{}} = Matches.create_match(scope, %{})
    end

    test "create_match/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      stage = insert(:stage)
      group = insert(:group, stage: stage)

      assert_raise FunctionClauseError, fn ->
        Matches.create_match(scope, %{event_id: stage.event_id, group_id: group.id})
      end
    end

    test "update_match/3 with valid data updates the match" do
      scope = Scope.for_user(insert(:superuser))
      match = insert(:match)

      assert {:ok, %Match{} = updated} =
               Matches.update_match(scope, match, %{scheduled_at: ~U[2026-07-01 09:00:00Z]})

      assert updated.scheduled_at == ~U[2026-07-01 09:00:00Z]
    end

    test "update_match/3 removing context returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      match = insert(:match)

      assert {:error, %Ecto.Changeset{}} =
               Matches.update_match(scope, match, %{group_id: nil})
    end

    test "update_match/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      match = insert(:match)

      assert_raise FunctionClauseError, fn ->
        Matches.update_match(scope, match, %{})
      end
    end

    test "delete_match/2 deletes the match" do
      scope = Scope.for_user(insert(:superuser))
      match = insert(:match)
      assert {:ok, %Match{}} = Matches.delete_match(scope, match)
      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(match.id) end
    end

    test "delete_match/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      match = insert(:match)

      assert_raise FunctionClauseError, fn -> Matches.delete_match(scope, match) end
    end

    test "change_match/1 returns a match changeset" do
      match = insert(:match)
      assert %Ecto.Changeset{} = Matches.change_match(match)
    end

    test "deleting a group cascades to its matches" do
      scope = Scope.for_user(insert(:superuser))
      match = insert(:match)
      group = T3System.Repo.preload(match, :group).group

      Matches.delete_group(scope, group)

      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(match.id) end
    end

    test "deleting a bracket stage cascades to its matches" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      category = insert(:category)

      {:ok, stage} =
        Matches.create_stage(scope, %{
          name: "Knockout",
          type: "bracket",
          order: 1,
          rounds: 2,
          event_id: event.id,
          category_id: category.id
        })

      matches = Matches.list_matches_for_event(event.id)
      assert length(matches) == 3

      Matches.delete_stage(scope, stage)

      assert Matches.list_matches_for_event(event.id) == []
    end

    test "create_match/2 with winner sets winner_registration_id" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      stage = insert(:stage, event: event)
      group = insert(:group, stage: stage)
      reg1 = insert(:registration, event: event)
      reg2 = insert(:registration, event: event)

      attrs = %{
        event_id: event.id,
        group_id: group.id,
        registration1_id: reg1.id,
        registration2_id: reg2.id,
        winner_registration_id: reg1.id
      }

      assert {:ok, %Match{} = match} = Matches.create_match(scope, attrs)
      assert match.winner_registration_id == reg1.id
    end

    test "create_match/2 with invalid winner returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      stage = insert(:stage, event: event)
      group = insert(:group, stage: stage)
      reg1 = insert(:registration, event: event)
      reg2 = insert(:registration, event: event)
      other_reg = insert(:registration)

      attrs = %{
        event_id: event.id,
        group_id: group.id,
        registration1_id: reg1.id,
        registration2_id: reg2.id,
        winner_registration_id: other_reg.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Matches.create_match(scope, attrs)
      assert %{winner_registration_id: [_]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # Match Sets
  # ---------------------------------------------------------------------------

  describe "match_sets" do
    test "list_sets_for_match/1 returns sets ordered by set_number" do
      match = insert(:match)
      set2 = insert(:match_set, match: match, set_number: 2, score1: 11, score2: 5)
      set1 = insert(:match_set, match: match, set_number: 1, score1: 8, score2: 11)

      results = Matches.list_sets_for_match(match.id)
      assert length(results) == 2
      assert hd(results).id == set1.id
      assert List.last(results).id == set2.id
    end

    test "get_match_set!/1 returns the set with given id" do
      set = insert(:match_set)
      result = Matches.get_match_set!(set.id)
      assert result.id == set.id
    end

    test "get_match_set!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn -> Matches.get_match_set!(0) end
    end

    test "create_match_set/2 creates a set" do
      scope = Scope.for_user(insert(:superuser))
      match = insert(:match)

      attrs = %{match_id: match.id, set_number: 1, score1: 11, score2: 7}

      assert {:ok, %MatchSet{} = set} = Matches.create_match_set(scope, attrs)
      assert set.set_number == 1
      assert set.score1 == 11
      assert set.score2 == 7
    end

    test "create_match_set/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      match = insert(:match)

      assert_raise FunctionClauseError, fn ->
        Matches.create_match_set(scope, %{match_id: match.id, set_number: 1})
      end
    end

    test "create_match_set/2 with winner_registration_id" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      stage = insert(:stage, event: event)
      group = insert(:group, stage: stage)
      reg1 = insert(:registration, event: event)
      reg2 = insert(:registration, event: event)

      match =
        insert(:match,
          event: event,
          group: group,
          registration1: reg1,
          registration2: reg2
        )

      attrs = %{
        match_id: match.id,
        set_number: 1,
        score1: 11,
        score2: 7,
        winner_registration_id: reg1.id
      }

      assert {:ok, %MatchSet{} = set} = Matches.create_match_set(scope, attrs)
      assert set.winner_registration_id == reg1.id
    end

    test "update_match_set/3 updates scores" do
      scope = Scope.for_user(insert(:superuser))
      match = insert(:match)
      set = insert(:match_set, match: match, set_number: 1, score1: 5, score2: 3)

      assert {:ok, %MatchSet{} = updated} =
               Matches.update_match_set(scope, set, %{score1: 11, score2: 8})

      assert updated.score1 == 11
      assert updated.score2 == 8
    end

    test "update_match_set/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      set = insert(:match_set)

      assert_raise FunctionClauseError, fn ->
        Matches.update_match_set(scope, set, %{score1: 11})
      end
    end

    test "delete_match_set/2 deletes the set" do
      scope = Scope.for_user(insert(:superuser))
      set = insert(:match_set)
      assert {:ok, %MatchSet{}} = Matches.delete_match_set(scope, set)
      assert_raise Ecto.NoResultsError, fn -> Matches.get_match_set!(set.id) end
    end

    test "delete_match_set/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      set = insert(:match_set)

      assert_raise FunctionClauseError, fn -> Matches.delete_match_set(scope, set) end
    end

    test "change_match_set/1 returns a match_set changeset" do
      set = insert(:match_set)
      assert %Ecto.Changeset{} = Matches.change_match_set(set)
    end

    test "deleting a match cascades to its sets" do
      scope = Scope.for_user(insert(:superuser))
      match = insert(:match)
      set = insert(:match_set, match: match, set_number: 1)

      Matches.delete_match(scope, match)

      assert_raise Ecto.NoResultsError, fn -> Matches.get_match_set!(set.id) end
    end

    test "get_match!/1 preloads sets" do
      match = insert(:match)
      insert(:match_set, match: match, set_number: 1, score1: 11, score2: 5)

      result = Matches.get_match!(match.id)
      assert length(result.sets) == 1
      assert hd(result.sets).set_number == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Team matches
  # ---------------------------------------------------------------------------

  describe "team matches" do
    test "get_team_match!/2 returns a team match of the event with its teams" do
      team_match = insert(:team_match)

      result = Matches.get_team_match!(team_match.event_id, team_match.id)

      assert result.id == team_match.id
      assert result.registration1.name == team_match.registration1.name
      assert length(result.registration2.registration_players) == 3
      assert result.group.stage.category.format == "team"
    end

    test "get_team_match!/2 finds bracket team matches" do
      event = insert(:event)
      stage = insert(:stage, event: event, category: build(:team_category), type: "bracket")
      match = insert(:match, event: event, group: nil, stage: stage, round: 1, position: 1)

      assert Matches.get_team_match!(event.id, match.id).id == match.id
    end

    test "get_team_match/2 returns the team match, or nil when it isn't one of the event" do
      team_match = insert(:team_match)

      assert %Match{inner_matches: []} =
               Matches.get_team_match(team_match.event_id, team_match.id)

      assert is_nil(Matches.get_team_match(insert(:event).id, team_match.id))
      assert is_nil(Matches.get_team_match(team_match.event_id, insert(:match).id))
    end

    test "get_team_match!/2 raises for a match of another event" do
      team_match = insert(:team_match)
      other_event = insert(:event)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.get_team_match!(other_event.id, team_match.id)
      end
    end

    test "get_team_match!/2 raises for a match outside a team category" do
      match = insert(:match)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.get_team_match!(match.event_id, match.id)
      end
    end

    test "team_match_score/2 counts the matches each team won" do
      team_match = insert(:team_match)
      %{registration1_id: t1, registration2_id: t2} = team_match

      inner = [
        %Match{registration1_id: t1, registration2_id: t2, winner_registration_id: t1},
        %Match{registration1_id: t1, registration2_id: t2, winner_registration_id: t2},
        %Match{registration1_id: t1, registration2_id: t2, winner_registration_id: t1},
        %Match{registration1_id: t1, registration2_id: t2, winner_registration_id: nil}
      ]

      assert Matches.team_match_score(team_match, inner) == {2, 1}
      assert Matches.team_match_score(team_match, []) == {0, 0}
    end

    test "team_match_status/2 is finished with a winner, ongoing once a match started" do
      team_match = insert(:team_match)
      %{registration1_id: t1, registration2_id: t2} = team_match
      pending = %Match{registration1_id: t1, registration2_id: t2}

      assert Matches.team_match_status(team_match, []) == :pending
      assert Matches.team_match_status(team_match, [pending]) == :pending

      assert Matches.team_match_status(team_match, [pending, %{pending | is_ongoing: true}]) ==
               :ongoing

      assert Matches.team_match_status(team_match, [%{pending | winner_registration_id: t2}]) ==
               :ongoing

      assert Matches.team_match_status(%{team_match | winner_registration_id: t1}, [pending]) ==
               :finished
    end

    test "update_match/3 sets and clears the team match winner" do
      scope = Scope.for_user(insert(:superuser))
      team_match = insert(:team_match)

      assert {:ok, won} =
               Matches.update_match(scope, team_match, %{
                 "winner_registration_id" => team_match.registration2_id
               })

      assert won.winner_registration_id == team_match.registration2_id
      assert {:ok, cleared} = Matches.update_match(scope, won, %{"winner_registration_id" => nil})
      assert is_nil(cleared.winner_registration_id)
    end
  end

  describe "matches inside a team match" do
    setup do
      team_match = insert(:team_match)
      team_match = Matches.get_team_match!(team_match.event_id, team_match.id)

      %{
        scope: Scope.for_user(insert(:superuser)),
        team_match: team_match,
        p1: player_ids(team_match.registration1),
        p2: player_ids(team_match.registration2)
      }
    end

    test "create_inner_match/3 adds a singles match between the two teams", ctx do
      %{scope: scope, team_match: tm, p1: [a | _], p2: [x | _]} = ctx

      assert {:ok, %Match{} = match} =
               Matches.create_inner_match(scope, tm, %{
                 "kind" => "singles",
                 "position1" => "A",
                 "position2" => "X",
                 "player_ids1" => [to_string(a)],
                 "player_ids2" => [to_string(x)]
               })

      assert match.event_id == tm.event_id
      assert match.team_match_id == tm.id
      assert match.registration1_id == tm.registration1_id
      assert match.registration2_id == tm.registration2_id

      assert [inner] = inner_matches(tm)
      assert inner.position1 == "A"
      assert inner.position2 == "X"

      assert inner.match_players |> Enum.map(&{&1.side, &1.player_id}) |> Enum.sort() ==
               [{1, a}, {2, x}]
    end

    test "create_inner_match/3 adds a doubles match with two players per side", ctx do
      %{scope: scope, team_match: tm, p1: [a, b | _], p2: [x, y | _]} = ctx

      assert {:ok, _} =
               Matches.create_inner_match(scope, tm, %{
                 "kind" => "doubles",
                 "position1" => "AB",
                 "position2" => "XY",
                 "player_ids1" => [a, b],
                 "player_ids2" => [x, y]
               })

      assert [inner] = inner_matches(tm)

      assert inner.match_players |> Enum.map(& &1.player_id) |> Enum.sort() ==
               Enum.sort([a, b, x, y])
    end

    test "create_inner_match/3 requires the player count of the kind", ctx do
      %{scope: scope, team_match: tm, p1: [a, b | _], p2: [x, y | _]} = ctx

      assert {:error, changeset} =
               Matches.create_inner_match(scope, tm, %{
                 "kind" => "singles",
                 "player_ids1" => [a, b],
                 "player_ids2" => []
               })

      assert errors_on(changeset)[:player_ids1]
      assert errors_on(changeset)[:player_ids2]

      assert {:error, changeset} =
               Matches.create_inner_match(scope, tm, %{
                 "kind" => "doubles",
                 "player_ids1" => [a, a],
                 "player_ids2" => [x, y]
               })

      assert errors_on(changeset)[:player_ids1]
      refute errors_on(changeset)[:player_ids2]
      assert inner_matches(tm) == []
    end

    test "create_inner_match/3 rejects a player who isn't in the side's team", ctx do
      %{scope: scope, team_match: tm, p1: [a | _], p2: [x | _]} = ctx
      outsider = insert(:player)

      assert {:error, changeset} =
               Matches.create_inner_match(scope, tm, %{
                 "kind" => "singles",
                 "player_ids1" => [x],
                 "player_ids2" => [outsider.id]
               })

      assert errors_on(changeset)[:player_ids1]
      assert errors_on(changeset)[:player_ids2]

      assert {:ok, _} =
               Matches.create_inner_match(scope, tm, %{
                 "kind" => "singles",
                 "player_ids1" => [a],
                 "player_ids2" => [x]
               })
    end

    test "a player may play several matches of one team match", ctx do
      %{scope: scope, team_match: tm, p1: [a, b | _], p2: [x, y | _]} = ctx

      for {p1, p2} <- [{[a], [y]}, {[a, b], [x, y]}, {[a], [x]}] do
        assert {:ok, _} =
                 Matches.create_inner_match(scope, tm, %{
                   "kind" => if(length(p1) == 1, do: "singles", else: "doubles"),
                   "player_ids1" => p1,
                   "player_ids2" => p2
                 })
      end

      assert length(inner_matches(tm)) == 3
    end

    test "an inner match can be put on a table, moved off it with an update", ctx do
      %{scope: scope, team_match: tm, p1: [a | _], p2: [x | _]} = ctx
      table = insert(:table, event_id: tm.event_id, event: nil)
      lineup = %{"kind" => "singles", "player_ids1" => [a], "player_ids2" => [x]}

      assert {:ok, match} =
               Matches.create_inner_match(scope, tm, Map.put(lineup, "table_id", "#{table.id}"))

      assert match.table_id == table.id
      assert match.scheduled_at

      [inner] = inner_matches(tm)

      assert {:ok, moved} =
               Matches.update_inner_match(scope, tm, inner, Map.put(lineup, "table_id", ""))

      assert is_nil(moved.table_id)
      assert is_nil(moved.scheduled_at)
    end

    test "create_inner_match/3 with non-superuser scope raises", ctx do
      assert_raise FunctionClauseError, fn ->
        Matches.create_inner_match(Scope.for_user(insert(:user)), ctx.team_match, %{})
      end
    end

    test "update_inner_match/4 changes the lineup and positions", ctx do
      %{scope: scope, team_match: tm, p1: [a, b, c], p2: [x, y | _]} = ctx
      insert(:inner_match, team_match: tm, players1: [a], players2: [x])
      [inner] = inner_matches(tm)

      assert {:ok, _} =
               Matches.update_inner_match(scope, tm, inner, %{
                 "kind" => "doubles",
                 "position1" => "BC",
                 "position2" => "XY",
                 "player_ids1" => [b, c],
                 "player_ids2" => [x, y]
               })

      assert [updated] = inner_matches(tm)
      assert updated.position1 == "BC"

      assert updated.match_players |> Enum.map(&{&1.side, &1.player_id}) |> Enum.sort() ==
               Enum.sort([{1, b}, {1, c}, {2, x}, {2, y}])
    end

    test "inner matches are ordered by creation and count in the score and status", ctx do
      %{scope: scope, team_match: tm} = ctx
      first = insert(:inner_match, team_match: tm, winner_registration_id: tm.registration1_id)
      second = insert(:inner_match, team_match: tm)

      inner = inner_matches(tm)
      assert Enum.map(inner, & &1.id) == [first.id, second.id]
      assert Matches.team_match_score(tm, inner) == {1, 0}
      assert Matches.team_match_status(tm, inner) == :ongoing

      {:ok, _} =
        Matches.update_match(scope, second, %{"winner_registration_id" => tm.registration2_id})

      assert Matches.team_match_score(tm, inner_matches(tm)) == {1, 1}
    end

    test "a match belongs to exactly one of a group, a stage or a team match", ctx do
      %{team_match: tm} = ctx

      changeset =
        Match.changeset(%Match{}, %{
          event_id: tm.event_id,
          group_id: tm.group_id,
          team_match_id: tm.id
        })

      refute changeset.valid?
      assert Match.changeset(%Match{}, %{event_id: tm.event_id, team_match_id: tm.id}).valid?

      assert_raise Ecto.ConstraintError, ~r/exactly_one_context/, fn ->
        T3System.Repo.insert!(%Match{
          event_id: tm.event_id,
          group_id: tm.group_id,
          team_match_id: tm.id
        })
      end
    end

    test "deleting the team match deletes the matches inside it", ctx do
      %{scope: scope, team_match: tm} = ctx
      inner = insert(:inner_match, team_match: tm)

      assert {:ok, _} = Matches.delete_match(scope, tm)
      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(inner.id) end
    end

    test "regenerating the group's matches deletes the matches inside team matches", ctx do
      %{scope: scope, team_match: tm} = ctx
      inner = insert(:inner_match, team_match: tm)
      group = Matches.get_group!(tm.group_id)

      Matches.add_registration_to_group(scope, group.id, tm.registration1_id)
      Matches.add_registration_to_group(scope, group.id, tm.registration2_id)
      assert {:ok, 1} = Matches.generate_group_matches(scope, group)
      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(inner.id) end
    end

    test "deleting the stage deletes the matches inside team matches", ctx do
      %{scope: scope, team_match: tm} = ctx
      inner = insert(:inner_match, team_match: tm)

      assert {:ok, _} = Matches.delete_stage(scope, tm.group.stage)
      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(inner.id) end
    end
  end

  describe "bracket team match slots" do
    setup do
      event = insert(:event)
      category = insert(:team_category)
      stage = insert(:stage, event: event, category: category, type: "bracket", rounds: 1)
      [t1, t2, t3] = for _ <- 1..3, do: insert(:team, event: event, category: category)

      match =
        insert(:match,
          event: event,
          group: nil,
          stage: stage,
          round: 1,
          position: 1,
          registration1: t1,
          registration2: t2
        )

      %{
        scope: Scope.for_user(insert(:superuser)),
        team_match: Matches.get_team_match!(event.id, match.id),
        t3: t3
      }
    end

    test "a team can't be swapped while the team match has matches inside it", ctx do
      %{scope: scope, team_match: tm, t3: t3} = ctx
      insert(:inner_match, team_match: tm)

      assert {:error, :has_inner_matches} =
               Matches.assign_bracket_slot_direct(scope, tm, 1, t3.id)

      assert Matches.get_match!(tm.id).registration1_id == tm.registration1_id
    end

    test "keeping the same team is allowed while it has matches inside it", ctx do
      %{scope: scope, team_match: tm} = ctx
      insert(:inner_match, team_match: tm)

      assert {:ok, _} = Matches.assign_bracket_slot_direct(scope, tm, 1, tm.registration1_id)
    end

    test "a team match without matches inside it can change teams", ctx do
      %{scope: scope, team_match: tm, t3: t3} = ctx

      assert {:ok, match} = Matches.assign_bracket_slot_direct(scope, tm, 2, t3.id)
      assert match.registration2_id == t3.id
    end
  end

  describe "deleting matches inside team matches reschedules their tables" do
    setup do
      event = insert(:event)
      category = insert(:team_category)
      group = insert(:group, stage: insert(:stage, event: event, category: category))

      tm =
        insert(:team_match,
          event: event,
          group: group,
          registration1: insert(:team, event: event, category: category),
          registration2: insert(:team, event: event, category: category)
        )

      tm = Matches.get_team_match!(event.id, tm.id)
      scope = Scope.for_user(insert(:superuser))
      table = insert(:table, event: event)

      inner = insert(:inner_match, team_match: tm)
      :ok = Matches.add_match_to_table(scope, event, inner.id, table.id)

      # A match of another stage, queued after the inner match
      other_group = insert(:group, stage: insert(:stage, event: event))
      later = insert(:match, event: event, group: other_group)
      :ok = Matches.add_match_to_table(scope, event, later.id, table.id)

      assert Repo.get!(Match, later.id).scheduled_at != event.datetime

      %{scope: scope, team_match: tm, event: event, later: later}
    end

    test "deleting the team match", ctx do
      assert {:ok, _} = Matches.delete_match(ctx.scope, ctx.team_match)
      assert Repo.get!(Match, ctx.later.id).scheduled_at == ctx.event.datetime
    end

    test "regenerating the group's matches", ctx do
      %{scope: scope, team_match: tm} = ctx
      group = Matches.get_group!(tm.group_id)

      assert {:ok, 0} = Matches.generate_group_matches(scope, group)
      assert Repo.get!(Match, ctx.later.id).scheduled_at == ctx.event.datetime
    end

    test "deleting the stage", ctx do
      assert {:ok, _} = Matches.delete_stage(ctx.scope, ctx.team_match.group.stage)
      assert Repo.get!(Match, ctx.later.id).scheduled_at == ctx.event.datetime
    end
  end

  describe "team group standings" do
    # Teams T1..T3 in a team category group
    setup do
      event = insert(:event)
      category = insert(:team_category)
      stage = insert(:stage, event: event, category: category)
      group = insert(:group, stage: stage)
      teams = for _ <- 1..3, do: insert(:team, event: event, category: category)
      now = DateTime.utc_now(:second)

      T3System.Repo.insert_all(
        "group_registrations",
        for(
          t <- teams,
          do: %{group_id: group.id, registration_id: t.id, inserted_at: now, updated_at: now}
        )
      )

      %{event: event, category: category, group: group, teams: teams}
    end

    # A team match between r1 and r2 whose inner matches are won by
    # `inner_winners`, each by one set 11-5
    defp team_match_between(ctx, r1, r2, winner, inner_winners) do
      tm =
        insert(:team_match,
          event: ctx.event,
          group: ctx.group,
          registration1: r1,
          registration2: r2,
          winner_registration_id: winner && winner.id
        )

      for w <- inner_winners do
        inner = insert(:inner_match, team_match: tm, winner_registration_id: w.id)
        {s1, s2} = if w.id == r1.id, do: {11, 5}, else: {5, 11}

        insert(:match_set,
          match: inner,
          set_number: 1,
          score1: s1,
          score2: s2,
          winner_registration_id: w.id
        )
      end

      tm
    end

    defp standings(ctx) do
      [group] = Matches.list_groups_for_event_and_category(ctx.event.id, ctx.category.id)
      Matches.compute_group_standings(group, team: true)
    end

    test "ranks by team match wins, then inner match difference", ctx do
      [t1, t2, t3] = ctx.teams
      # T1 and T2 both win one team match; T1 by 3-0, T2 by 2-1
      team_match_between(ctx, t1, t3, t1, [t1, t1, t1])
      team_match_between(ctx, t2, t3, t2, [t2, t3, t2])
      # T1 x T2 not finished yet, one inner match each
      team_match_between(ctx, t1, t2, nil, [t2, t1])

      rows = standings(ctx)

      assert Enum.map(rows, & &1.registration.id) == [t1.id, t2.id, t3.id]

      assert Enum.map(rows, &{&1.won, &1.lost, &1.match_diff}) ==
               [{1, 0, 3}, {1, 0, 1}, {0, 2, -4}]

      assert hd(rows).set_diff == 3
      assert hd(rows).point_diff == 18
    end

    test "breaks match difference ties by set difference", ctx do
      [t1, t2, t3] = ctx.teams
      team_match_between(ctx, t2, t3, t2, [t2, t3, t2])
      tm = team_match_between(ctx, t1, t3, t1, [t1, t3, t1])
      # An extra set won by T1 in one of its inner matches
      [inner | _] = inner_matches(tm)

      insert(:match_set,
        match: inner,
        set_number: 2,
        score1: 11,
        score2: 9,
        winner_registration_id: t1.id
      )

      assert Enum.map(standings(ctx), & &1.registration.id) == [t1.id, t2.id, t3.id]
    end
  end

  defp player_ids(team), do: Enum.map(team.registration_players, & &1.player_id)

  defp inner_matches(team_match),
    do: Matches.get_team_match!(team_match.event_id, team_match.id).inner_matches

  # ---------------------------------------------------------------------------
  # Dashboard metrics
  # ---------------------------------------------------------------------------

  describe "count_matches_per_category/1" do
    test "returns counts grouped by category name" do
      event = insert(:event)
      cat_a = insert(:category, name: "Alpha")
      cat_b = insert(:category, name: "Beta")
      stage_a = insert(:stage, event: event, category: cat_a, order: 1)
      stage_b = insert(:stage, event: event, category: cat_b, order: 2)
      group_a = insert(:group, stage: stage_a)
      group_b = insert(:group, stage: stage_b)

      insert(:match, event: event, group: group_a)
      insert(:match, event: event, group: group_a)
      insert(:match, event: event, group: group_b)

      result = Matches.count_matches_per_category(event.id)

      assert [%{category_name: "Alpha", count: 2}, %{category_name: "Beta", count: 1}] = result
    end

    test "includes bracket matches" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      category = insert(:category, name: "Singles")

      {:ok, _stage} =
        Matches.create_stage(scope, %{
          name: "Knockout",
          type: "bracket",
          order: 1,
          rounds: 2,
          event_id: event.id,
          category_id: category.id
        })

      result = Matches.count_matches_per_category(event.id)

      assert [%{category_name: "Singles", count: 3}] = result
    end

    test "excludes byes" do
      event = insert(:event)
      cat = insert(:category, name: "Cat")
      stage = insert(:stage, event: event, category: cat, order: 1)
      group = insert(:group, stage: stage)

      insert(:match, event: event, group: group)
      insert(:match, event: event, group: group, is_bye: true)

      assert [%{category_name: "Cat", count: 1}] = Matches.count_matches_per_category(event.id)
    end

    test "returns empty list for event with no matches" do
      event = insert(:event)
      assert Matches.count_matches_per_category(event.id) == []
    end

    test "ignores matches from other events" do
      event = insert(:event)
      other_event = insert(:event)
      cat = insert(:category, name: "Cat")
      stage = insert(:stage, event: event, category: cat, order: 1)
      other_stage = insert(:stage, event: other_event, category: cat, order: 1)
      group = insert(:group, stage: stage)
      other_group = insert(:group, stage: other_stage)

      insert(:match, event: event, group: group)
      insert(:match, event: other_event, group: other_group)

      result = Matches.count_matches_per_category(event.id)
      assert [%{category_name: "Cat", count: 1}] = result
    end
  end

  describe "count_matches_by_status/1" do
    test "returns finished and unfinished counts" do
      event = insert(:event)
      stage = insert(:stage, event: event)
      group = insert(:group, stage: stage)
      reg1 = insert(:registration, event: event)
      reg2 = insert(:registration, event: event)

      # Finished match
      insert(:match,
        event: event,
        group: group,
        registration1: reg1,
        registration2: reg2,
        winner: reg1
      )

      # Unfinished matches
      insert(:match, event: event, group: group)
      insert(:match, event: event, group: group)

      result = Matches.count_matches_by_status(event.id)
      assert result == %{finished: 1, unfinished: 2}
    end

    test "excludes byes" do
      event = insert(:event)
      stage = insert(:stage, event: event)
      group = insert(:group, stage: stage)
      reg = insert(:registration, event: event)

      insert(:match, event: event, group: group)
      insert(:match, event: event, group: group, is_bye: true)
      insert(:match, event: event, group: group, registration1: reg, winner: reg, is_bye: true)

      assert Matches.count_matches_by_status(event.id) == %{finished: 0, unfinished: 1}
    end

    test "returns zeros for event with no matches" do
      event = insert(:event)
      result = Matches.count_matches_by_status(event.id)
      assert result == %{finished: 0, unfinished: 0}
    end
  end

  describe "count_matches_per_table/1" do
    test "returns per-table counts and unassigned count" do
      event = insert(:event)
      table1 = insert(:table, event: event)
      table2 = insert(:table, event: event)
      stage = insert(:stage, event: event)
      group = insert(:group, stage: stage)
      reg1 = insert(:registration, event: event)
      reg2 = insert(:registration, event: event)

      # Table 1: 1 finished, 1 unfinished
      insert(:match,
        event: event,
        group: group,
        table: table1,
        registration1: reg1,
        registration2: reg2,
        winner: reg1
      )

      insert(:match, event: event, group: group, table: table1)

      # Table 2: 1 unfinished
      insert(:match, event: event, group: group, table: table2)

      # Unassigned: 2 unfinished, 1 finished (finished should not count)
      insert(:match, event: event, group: group)
      insert(:match, event: event, group: group)

      insert(:match,
        event: event,
        group: group,
        registration1: reg1,
        registration2: reg2,
        winner: reg2
      )

      {table_counts, unassigned} = Matches.count_matches_per_table(event.id)

      assert table_counts[table1.id] == %{finished: 1, unfinished: 1}
      assert table_counts[table2.id] == %{finished: 0, unfinished: 1}
      assert unassigned == 2
    end

    test "excludes byes" do
      event = insert(:event)
      table = insert(:table, event: event)
      stage = insert(:stage, event: event)
      group = insert(:group, stage: stage)

      insert(:match, event: event, group: group, table: table)
      insert(:match, event: event, group: group, table: table, is_bye: true)
      insert(:match, event: event, group: group)
      insert(:match, event: event, group: group, is_bye: true)

      {table_counts, unassigned} = Matches.count_matches_per_table(event.id)

      assert table_counts[table.id] == %{finished: 0, unfinished: 1}
      assert unassigned == 1
    end

    test "returns empty map and zero for event with no matches" do
      event = insert(:event)
      {table_counts, unassigned} = Matches.count_matches_per_table(event.id)
      assert table_counts == %{}
      assert unassigned == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Table schedule
  # ---------------------------------------------------------------------------

  describe "table schedule" do
    setup do
      event = insert(:event, datetime: ~U[2026-03-07 12:00:00Z], match_duration_minutes: 20)
      category = insert(:category)
      stage = insert(:stage, event: event, category: category)
      group = insert(:group, stage: stage)

      %{
        scope: Scope.for_user(insert(:superuser)),
        event: event,
        category: category,
        group: group,
        table1: insert(:table, event: event),
        table2: insert(:table, event: event)
      }
    end

    defp pending_match(ctx, attrs \\ []) do
      insert(:match, [event: ctx.event, group: ctx.group] ++ attrs)
    end

    defp finished_match(ctx, attrs) do
      reg1 = insert(:registration, event: ctx.event, category: ctx.category)
      reg2 = insert(:registration, event: ctx.event, category: ctx.category)

      insert(
        :match,
        [
          event: ctx.event,
          group: ctx.group,
          registration1: reg1,
          registration2: reg2,
          winner: reg1
        ] ++ attrs
      )
    end

    defp times(match_ids) do
      Enum.map(match_ids, &Repo.get!(Match, &1).scheduled_at)
    end

    test "assigning matches to a table schedules them from the event start", ctx do
      [m1, m2, m3] = for _ <- 1..3, do: pending_match(ctx)

      :ok =
        Matches.update_table_schedule(ctx.scope, ctx.event, [
          %{table_id: ctx.table1.id, match_ids: [m2.id, m1.id, m3.id]}
        ])

      assert times([m2.id, m1.id, m3.id]) == [
               ~U[2026-03-07 12:00:00Z],
               ~U[2026-03-07 12:20:00Z],
               ~U[2026-03-07 12:40:00Z]
             ]

      assert [%{pending: pending}, %{pending: []}] = Matches.list_table_schedules(ctx.event.id)
      assert Enum.map(pending, & &1.id) == [m2.id, m1.id, m3.id]
    end

    test "moving a match between tables recalculates both tables", ctx do
      [m1, m2, m3] = for _ <- 1..3, do: pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [m1.id, m2.id, m3.id]}
      ])

      # m1 moves to table 2. Even with only the destination list sent, the
      # table it left must be recalculated.
      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table2.id, match_ids: [m1.id]}
      ])

      assert times([m2.id, m3.id, m1.id]) == [
               ~U[2026-03-07 12:00:00Z],
               ~U[2026-03-07 12:20:00Z],
               ~U[2026-03-07 12:00:00Z]
             ]

      assert Repo.get!(Match, m1.id).table_id == ctx.table2.id
    end

    test "finished matches are frozen and anchor the pending queue", ctx do
      finished = finished_match(ctx, table: ctx.table1, scheduled_at: ~U[2026-03-07 13:05:00Z])
      [m1, m2] = for _ <- 1..2, do: pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [finished.id, m1.id, m2.id]}
      ])

      assert times([finished.id, m1.id, m2.id]) == [
               ~U[2026-03-07 13:05:00Z],
               ~U[2026-03-07 13:25:00Z],
               ~U[2026-03-07 13:45:00Z]
             ]

      # Finished matches can't be moved
      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table2.id, match_ids: [finished.id]}
      ])

      assert Repo.get!(Match, finished.id).table_id == ctx.table1.id

      assert [%{finished: [f], pending: [p1, p2]}, _] = Matches.list_table_schedules(ctx.event.id)
      assert {f.id, p1.id, p2.id} == {finished.id, m1.id, m2.id}
    end

    test "moving a match back to the pool clears its table and time", ctx do
      [m1, m2] = for _ <- 1..2, do: pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [m1.id, m2.id]}
      ])

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: nil, match_ids: [m1.id]}
      ])

      m1 = Repo.get!(Match, m1.id)
      assert {m1.table_id, m1.scheduled_at} == {nil, nil}
      assert times([m2.id]) == [~U[2026-03-07 12:00:00Z]]
    end

    test "ignores tables and matches from other events", ctx do
      other_table = insert(:table)
      other_match = insert(:match)
      m1 = pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: other_table.id, match_ids: [m1.id]},
        %{table_id: ctx.table1.id, match_ids: [other_match.id]}
      ])

      assert Repo.get!(Match, m1.id).table_id == nil
      assert Repo.get!(Match, other_match.id).table_id == nil
    end

    test "update_match_duration/3 recalculates pending matches of every table", ctx do
      finished = finished_match(ctx, table: ctx.table1, scheduled_at: ~U[2026-03-07 12:00:00Z])
      m1 = pending_match(ctx)
      m2 = pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [m1.id]},
        %{table_id: ctx.table2.id, match_ids: [m2.id]}
      ])

      assert {:ok, event} =
               Matches.update_match_duration(ctx.scope, ctx.event, %{
                 "match_duration_minutes" => "30"
               })

      assert event.match_duration_minutes == 30

      assert times([finished.id, m1.id, m2.id]) == [
               ~U[2026-03-07 12:00:00Z],
               ~U[2026-03-07 12:30:00Z],
               ~U[2026-03-07 12:00:00Z]
             ]
    end

    test "update_match_duration/3 rejects non-positive durations", ctx do
      assert {:error, changeset} =
               Matches.update_match_duration(ctx.scope, ctx.event, %{
                 "match_duration_minutes" => "0"
               })

      assert "must be greater than 0" in errors_on(changeset).match_duration_minutes
    end

    test "add_match_to_table/4 appends a match to the end of the queue", ctx do
      m1 = pending_match(ctx)
      m2 = pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [m1.id]}
      ])

      assert :ok = Matches.add_match_to_table(ctx.scope, ctx.event, m2.id, ctx.table1.id)

      assert [%{pending: [p1, p2]}, _] = Matches.list_table_schedules(ctx.event.id)
      assert {p1.id, p2.id} == {m1.id, m2.id}
      assert times([m1.id, m2.id]) == [~U[2026-03-07 12:00:00Z], ~U[2026-03-07 12:20:00Z]]
    end

    test "add_match_to_table/4 moving from another table recalculates it", ctx do
      [m1, m2] = for _ <- 1..2, do: pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [m1.id, m2.id]}
      ])

      assert :ok = Matches.add_match_to_table(ctx.scope, ctx.event, m1.id, ctx.table2.id)
      assert times([m2.id, m1.id]) == [~U[2026-03-07 12:00:00Z], ~U[2026-03-07 12:00:00Z]]
    end

    test "add_match_to_table/4 rejects finished matches and foreign tables", ctx do
      finished = finished_match(ctx, [])
      pending = pending_match(ctx)

      assert {:error, :not_found} =
               Matches.add_match_to_table(ctx.scope, ctx.event, finished.id, ctx.table1.id)

      assert {:error, :not_found} =
               Matches.add_match_to_table(ctx.scope, ctx.event, pending.id, insert(:table).id)
    end

    test "set_match_ongoing/4 marks only the first pending match of a table", ctx do
      [m1, m2] = for _ <- 1..2, do: pending_match(ctx)
      unscheduled = pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [m1.id, m2.id]}
      ])

      assert {:error, :not_found} = Matches.set_match_ongoing(ctx.scope, ctx.event, m2.id, true)

      assert {:error, :not_found} =
               Matches.set_match_ongoing(ctx.scope, ctx.event, unscheduled.id, true)

      assert :ok = Matches.set_match_ongoing(ctx.scope, ctx.event, m1.id, true)
      assert Repo.get!(Match, m1.id).is_ongoing

      assert :ok = Matches.set_match_ongoing(ctx.scope, ctx.event, m1.id, false)
      refute Repo.get!(Match, m1.id).is_ongoing
    end

    test "set_match_ongoing/4 skips finished matches at the top of the queue", ctx do
      finished_match(ctx, table: ctx.table1, table_position: 0)
      m1 = pending_match(ctx, table: ctx.table1, table_position: 1)

      assert :ok = Matches.set_match_ongoing(ctx.scope, ctx.event, m1.id, true)
    end

    test "a match pushed down the queue stops being ongoing", ctx do
      [m1, m2] = for _ <- 1..2, do: pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [m1.id, m2.id]}
      ])

      :ok = Matches.set_match_ongoing(ctx.scope, ctx.event, m1.id, true)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [m2.id, m1.id]}
      ])

      refute Repo.get!(Match, m1.id).is_ongoing
    end

    test "a match moved back to the pool stops being ongoing", ctx do
      m1 = pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [m1.id]}
      ])

      :ok = Matches.set_match_ongoing(ctx.scope, ctx.event, m1.id, true)
      Matches.update_table_schedule(ctx.scope, ctx.event, [%{table_id: nil, match_ids: [m1.id]}])

      refute Repo.get!(Match, m1.id).is_ongoing
    end

    test "a match moved to another table stops being ongoing", ctx do
      m1 = pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [m1.id]}
      ])

      :ok = Matches.set_match_ongoing(ctx.scope, ctx.event, m1.id, true)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: []},
        %{table_id: ctx.table2.id, match_ids: [m1.id]}
      ])

      refute Repo.get!(Match, m1.id).is_ongoing
    end

    test "an ongoing match keeps its time and anchors the matches that follow it", ctx do
      [m1, m2] = for _ <- 1..2, do: pending_match(ctx)

      Matches.update_table_schedule(ctx.scope, ctx.event, [
        %{table_id: ctx.table1.id, match_ids: [m1.id, m2.id]}
      ])

      :ok = Matches.set_match_ongoing(ctx.scope, ctx.event, m1.id, true)

      {:ok, _} =
        Matches.update_match(ctx.scope, Repo.get!(Match, m1.id), %{
          scheduled_at: ~U[2026-03-07 12:15:00Z]
        })

      :ok = Matches.recalculate_table_schedule(ctx.scope, ctx.event, ctx.table1.id)
      assert times([m1.id, m2.id]) == [~U[2026-03-07 12:15:00Z], ~U[2026-03-07 12:35:00Z]]

      # Once it's no longer ongoing, the times follow the event start again
      :ok = Matches.set_match_ongoing(ctx.scope, ctx.event, m1.id, false)
      assert times([m1.id, m2.id]) == [~U[2026-03-07 12:00:00Z], ~U[2026-03-07 12:20:00Z]]
    end

    test "finishing a match clears its ongoing flag", ctx do
      reg1 = insert(:registration, event: ctx.event, category: ctx.category)
      reg2 = insert(:registration, event: ctx.event, category: ctx.category)

      match =
        pending_match(ctx, registration1: reg1, registration2: reg2, is_ongoing: true)

      assert {:ok, match} =
               Matches.update_match(ctx.scope, match, %{winner_registration_id: reg1.id})

      refute match.is_ongoing
    end

    test "list_unscheduled_matches/1 lists every category, ordered by category name", ctx do
      other_category = insert(:category, name: "AAA")
      other_stage = insert(:stage, event: ctx.event, category: other_category)
      other_group = insert(:group, stage: other_stage)
      m1 = pending_match(ctx)
      m2 = insert(:match, event: ctx.event, group: other_group)

      assert Enum.map(Matches.list_unscheduled_matches(ctx.event.id), & &1.id) == [m2.id, m1.id]
    end

    test "list_unscheduled_matches/2 lists only pending matches without a table", ctx do
      unscheduled = pending_match(ctx)
      _assigned = pending_match(ctx, table: ctx.table1)
      _finished = finished_match(ctx, [])
      _bye = pending_match(ctx, is_bye: true)
      _other_category = insert(:match, event: ctx.event)

      assert [match] = Matches.list_unscheduled_matches(ctx.event.id, ctx.category.id)
      assert match.id == unscheduled.id
    end
  end

  describe "schedule and counts in team categories" do
    setup do
      event = insert(:event, datetime: ~U[2026-03-07 12:00:00Z], match_duration_minutes: 20)
      category = insert(:team_category, name: "Equipes")
      stage = insert(:stage, event: event, category: category)
      group = insert(:group, stage: stage)
      team1 = insert(:team, event: event, category: category, name: "AABB A")
      team2 = insert(:team, event: event, category: category, name: "Clube Y")

      team_match =
        insert(:team_match,
          event: event,
          group: group,
          registration1: team1,
          registration2: team2
        )

      %{
        scope: Scope.for_user(insert(:superuser)),
        event: event,
        category: category,
        team_match: team_match,
        table: insert(:table, event: event)
      }
    end

    defp finished_inner_match(ctx, attrs \\ []) do
      insert(
        :inner_match,
        [team_match: ctx.team_match, winner_registration_id: ctx.team_match.registration1_id] ++
          attrs
      )
    end

    test "the unscheduled pool lists inner matches, never team matches", ctx do
      inner = insert(:inner_match, team_match: ctx.team_match)
      _finished = finished_inner_match(ctx)

      assert [match] = Matches.list_unscheduled_matches(ctx.event.id)
      assert match.id == inner.id
      assert match.team_match.registration1.name == "AABB A"

      assert [%{id: id}] = Matches.list_unscheduled_matches(ctx.event.id, ctx.category.id)
      assert id == inner.id
    end

    test "inner matches are scheduled, toggled ongoing and listed on tables", ctx do
      inner1 = insert(:inner_match, team_match: ctx.team_match)
      inner2 = insert(:inner_match, team_match: ctx.team_match)

      :ok =
        Matches.update_table_schedule(ctx.scope, ctx.event, [
          %{table_id: ctx.table.id, match_ids: [inner1.id]}
        ])

      :ok = Matches.add_match_to_table(ctx.scope, ctx.event, inner2.id, ctx.table.id)
      :ok = Matches.set_match_ongoing(ctx.scope, ctx.event, inner1.id, true)

      assert [%{pending: [first, second]}] = Matches.list_table_schedules(ctx.event.id)

      assert {first.id, first.is_ongoing, first.scheduled_at} ==
               {inner1.id, true, ctx.event.datetime}

      assert {second.id, second.scheduled_at} == {inner2.id, ~U[2026-03-07 12:20:00Z]}
      assert first.team_match.registration2.name == "Clube Y"
    end

    test "team matches can't be put on a table", ctx do
      tm = ctx.team_match

      assert {:error, :not_found} =
               Matches.add_match_to_table(ctx.scope, ctx.event, tm.id, ctx.table.id)

      :ok =
        Matches.update_table_schedule(ctx.scope, ctx.event, [
          %{table_id: ctx.table.id, match_ids: [tm.id]}
        ])

      assert Repo.get!(Match, tm.id).table_id == nil
      assert [%{pending: [], finished: []}] = Matches.list_table_schedules(ctx.event.id)
    end

    test "counts and the unassigned count include inner matches, not team matches", ctx do
      _pending = insert(:inner_match, team_match: ctx.team_match)
      _on_table = insert(:inner_match, team_match: ctx.team_match, table: ctx.table)
      _finished = finished_inner_match(ctx, table: ctx.table)

      assert Matches.count_matches_per_category(ctx.event.id) == [
               %{category_name: "Equipes", count: 3}
             ]

      assert Matches.count_matches_by_status(ctx.event.id) == %{finished: 1, unfinished: 2}

      table_id = ctx.table.id

      assert {%{^table_id => %{finished: 1, unfinished: 1}}, 1} =
               Matches.count_matches_per_table(ctx.event.id)
    end

    test "list_pending_inner_matches/1 lists unfinished inner matches with their team match",
         ctx do
      inner = insert(:inner_match, team_match: ctx.team_match, position1: "A", position2: "X")
      _finished = finished_inner_match(ctx)
      _regular = insert(:match, event: ctx.event)

      assert [match] = Matches.list_pending_inner_matches(ctx.event.id)
      assert match.id == inner.id
      assert match.team_match.registration2.name == "Clube Y"
      assert [%{side: 1, player: %{}}, %{side: 2}] = match.match_players
    end

    test "get_inner_match/2 gets a match inside a team match of the event", ctx do
      inner = insert(:inner_match, team_match: ctx.team_match)
      regular = insert(:match, event: ctx.event)

      assert %Match{sets: [], match_players: [_, _]} =
               match = Matches.get_inner_match(ctx.event.id, inner.id)

      assert match.team_match.registration2.name == "Clube Y"
      assert is_nil(Matches.get_inner_match(ctx.event.id, regular.id))
      assert is_nil(Matches.get_inner_match(insert(:event).id, inner.id))
    end
  end

  describe "event broadcasts" do
    setup do
      event = insert(:event)
      stage = insert(:stage, event: event)
      Events.subscribe_event(event.id)

      %{scope: Scope.for_user(insert(:superuser)), event: event, stage: stage}
    end

    # Changes made by the test process itself are not broadcast back to it
    defp in_other_process(fun), do: fun |> Task.async() |> Task.await()

    test "group changes notify the subscribers of the stage's event", ctx do
      in_other_process(fn ->
        Matches.create_group(ctx.scope, %{"name" => "Grupo A", "stage_id" => ctx.stage.id})
      end)

      event_id = ctx.event.id
      assert_received {:event_updated, ^event_id}
    end

    test "group membership changes notify the event subscribers", ctx do
      group = insert(:group, stage: ctx.stage)
      registration = insert(:registration, event: ctx.event)

      in_other_process(fn ->
        Matches.add_registration_to_group(ctx.scope, group.id, registration.id)
      end)

      event_id = ctx.event.id
      assert_received {:event_updated, ^event_id}
    end

    test "match changes notify the event subscribers", ctx do
      match = insert(:match, event: ctx.event, stage: ctx.stage, group: nil)

      in_other_process(fn -> Matches.update_match(ctx.scope, match, %{"slot1_label" => "1A"}) end)

      event_id = ctx.event.id
      assert_received {:event_updated, ^event_id}
    end

    test "failed changes are not broadcast", ctx do
      in_other_process(fn -> Matches.create_group(ctx.scope, %{"stage_id" => ctx.stage.id}) end)

      refute_received {:event_updated, _}
    end
  end
end
