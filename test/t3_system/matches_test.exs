defmodule T3System.MatchesTest do
  use T3System.DataCase

  alias T3System.Accounts.Scope
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
end
