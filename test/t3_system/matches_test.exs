defmodule T3System.MatchesTest do
  use T3System.DataCase

  alias T3System.Accounts.Scope
  alias T3System.Matches
  alias T3System.Matches.Bracket
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.MatchSet

  import T3System.Factory

  # ---------------------------------------------------------------------------
  # Groups
  # ---------------------------------------------------------------------------

  describe "groups" do
    test "list_groups_for_event/1 returns groups for the event" do
      group = insert(:group)
      other_event = insert(:event)
      _other_group = insert(:group, event: other_event)

      results = Matches.list_groups_for_event(group.event_id)
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
      event = insert(:event)

      assert {:ok, %Group{} = group} =
               Matches.create_group(scope, %{name: "Group A", event_id: event.id})

      assert group.name == "Group A"
      assert group.event_id == event.id
    end

    test "create_group/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      assert {:error, %Ecto.Changeset{}} = Matches.create_group(scope, %{})
    end

    test "create_group/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      event = insert(:event)

      assert_raise FunctionClauseError, fn ->
        Matches.create_group(scope, %{name: "Group A", event_id: event.id})
      end
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
  # Brackets
  # ---------------------------------------------------------------------------

  describe "brackets" do
    test "list_brackets_for_event/1 returns brackets for the event" do
      bracket = insert(:bracket)
      other_event = insert(:event)
      _other_bracket = insert(:bracket, event: other_event)

      results = Matches.list_brackets_for_event(bracket.event_id)
      assert length(results) == 1
      assert hd(results).id == bracket.id
    end

    test "get_bracket!/1 returns the bracket with given id" do
      bracket = insert(:bracket)
      result = Matches.get_bracket!(bracket.id)
      assert result.id == bracket.id
    end

    test "get_bracket!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn -> Matches.get_bracket!(0) end
    end

    test "create_bracket/2 with valid data creates a bracket" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)

      assert {:ok, %Bracket{} = bracket} =
               Matches.create_bracket(scope, %{name: "Main Draw", event_id: event.id})

      assert bracket.name == "Main Draw"
      assert bracket.event_id == event.id
    end

    test "create_bracket/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      assert {:error, %Ecto.Changeset{}} = Matches.create_bracket(scope, %{})
    end

    test "create_bracket/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      event = insert(:event)

      assert_raise FunctionClauseError, fn ->
        Matches.create_bracket(scope, %{name: "Main Draw", event_id: event.id})
      end
    end

    test "update_bracket/3 with valid data updates the bracket" do
      scope = Scope.for_user(insert(:superuser))
      bracket = insert(:bracket)

      assert {:ok, %Bracket{} = updated} =
               Matches.update_bracket(scope, bracket, %{name: "Consolation"})

      assert updated.name == "Consolation"
    end

    test "update_bracket/3 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      bracket = insert(:bracket)

      assert {:error, %Ecto.Changeset{}} = Matches.update_bracket(scope, bracket, %{name: nil})
    end

    test "update_bracket/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      bracket = insert(:bracket)

      assert_raise FunctionClauseError, fn ->
        Matches.update_bracket(scope, bracket, %{name: "Consolation"})
      end
    end

    test "delete_bracket/2 deletes the bracket" do
      scope = Scope.for_user(insert(:superuser))
      bracket = insert(:bracket)
      assert {:ok, %Bracket{}} = Matches.delete_bracket(scope, bracket)
      assert_raise Ecto.NoResultsError, fn -> Matches.get_bracket!(bracket.id) end
    end

    test "delete_bracket/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      bracket = insert(:bracket)

      assert_raise FunctionClauseError, fn -> Matches.delete_bracket(scope, bracket) end
    end

    test "change_bracket/1 returns a bracket changeset" do
      bracket = insert(:bracket)
      assert %Ecto.Changeset{} = Matches.change_bracket(bracket)
    end
  end

  # ---------------------------------------------------------------------------
  # Matches
  # ---------------------------------------------------------------------------

  describe "matches" do
    test "list_matches_for_event/1 returns matches for the event with preloads" do
      match = insert(:match)
      other_event = insert(:event)
      _other_match = insert(:match, event: other_event, group: insert(:group, event: other_event))

      results = Matches.list_matches_for_event(match.event_id)
      assert length(results) == 1
      [result] = results
      assert result.id == match.id
      assert %Group{} = result.group
    end

    test "get_match!/1 returns the match with given id and preloads" do
      group = insert(:group)
      match = insert(:match, event: group.event, group: group)
      result = Matches.get_match!(match.id)
      assert result.id == match.id
      assert %Group{} = result.group
    end

    test "get_match!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(0) end
    end

    test "create_match/2 with group context creates a match" do
      scope = Scope.for_user(insert(:superuser))
      group = insert(:group)

      attrs = %{event_id: group.event_id, group_id: group.id}

      assert {:ok, %Match{} = match} = Matches.create_match(scope, attrs)
      assert match.group_id == group.id
      assert match.event_id == group.event_id
      assert match.bracket_id == nil
    end

    test "create_match/2 with bracket context creates a match" do
      scope = Scope.for_user(insert(:superuser))
      bracket = insert(:bracket)

      attrs = %{event_id: bracket.event_id, bracket_id: bracket.id, round: 1, position: 1}

      assert {:ok, %Match{} = match} = Matches.create_match(scope, attrs)
      assert match.bracket_id == bracket.id
      assert match.round == 1
      assert match.position == 1
      assert match.group_id == nil
    end

    test "create_match/2 with participants creates a match" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      group = insert(:group, event: event)
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

    test "create_match/2 with next_match_id links bracket matches" do
      scope = Scope.for_user(insert(:superuser))
      bracket = insert(:bracket)

      {:ok, semifinal} =
        Matches.create_match(scope, %{
          event_id: bracket.event_id,
          bracket_id: bracket.id,
          round: 2,
          position: 1
        })

      {:ok, quarterfinal} =
        Matches.create_match(scope, %{
          event_id: bracket.event_id,
          bracket_id: bracket.id,
          round: 1,
          position: 1,
          next_match_id: semifinal.id
        })

      assert quarterfinal.next_match_id == semifinal.id
    end

    test "create_match/2 without group or bracket returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Matches.create_match(scope, %{event_id: event.id})

      assert %{base: [_]} = errors_on(changeset)
    end

    test "create_match/2 with both group and bracket returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      group = insert(:group, event: event)
      bracket = insert(:bracket, event: event)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Matches.create_match(scope, %{
                 event_id: event.id,
                 group_id: group.id,
                 bracket_id: bracket.id
               })

      assert %{base: [_]} = errors_on(changeset)
    end

    test "create_match/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      assert {:error, %Ecto.Changeset{}} = Matches.create_match(scope, %{})
    end

    test "create_match/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      group = insert(:group)

      assert_raise FunctionClauseError, fn ->
        Matches.create_match(scope, %{event_id: group.event_id, group_id: group.id})
      end
    end

    test "update_match/3 with valid data updates the match" do
      scope = Scope.for_user(insert(:superuser))
      group = insert(:group)
      match = insert(:match, event: group.event, group: group)

      assert {:ok, %Match{} = updated} =
               Matches.update_match(scope, match, %{scheduled_at: ~U[2026-07-01 09:00:00Z]})

      assert updated.scheduled_at == ~U[2026-07-01 09:00:00Z]
    end

    test "update_match/3 removing context returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      group = insert(:group)
      match = insert(:match, event: group.event, group: group)

      assert {:error, %Ecto.Changeset{}} =
               Matches.update_match(scope, match, %{group_id: nil})
    end

    test "update_match/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      group = insert(:group)
      match = insert(:match, event: group.event, group: group)

      assert_raise FunctionClauseError, fn ->
        Matches.update_match(scope, match, %{})
      end
    end

    test "delete_match/2 deletes the match" do
      scope = Scope.for_user(insert(:superuser))
      group = insert(:group)
      match = insert(:match, event: group.event, group: group)
      assert {:ok, %Match{}} = Matches.delete_match(scope, match)
      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(match.id) end
    end

    test "delete_match/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      group = insert(:group)
      match = insert(:match, event: group.event, group: group)

      assert_raise FunctionClauseError, fn -> Matches.delete_match(scope, match) end
    end

    test "change_match/1 returns a match changeset" do
      group = insert(:group)
      match = insert(:match, event: group.event, group: group)
      assert %Ecto.Changeset{} = Matches.change_match(match)
    end

    test "deleting a group cascades to its matches" do
      scope = Scope.for_user(insert(:superuser))
      group = insert(:group)
      match = insert(:match, event: group.event, group: group)

      Matches.delete_group(scope, group)

      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(match.id) end
    end

    test "deleting a bracket cascades to its matches" do
      scope = Scope.for_user(insert(:superuser))
      bracket = insert(:bracket)
      match = insert(:match, event: bracket.event, bracket: bracket, group: nil)

      Matches.delete_bracket(scope, bracket)

      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(match.id) end
    end

    test "create_match/2 with winner sets winner_registration_id" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      group = insert(:group, event: event)
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
      group = insert(:group, event: event)
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

    test "create_match/2 in bracket sets best_of and points_per_set" do
      scope = Scope.for_user(insert(:superuser))
      bracket = insert(:bracket)

      attrs = %{
        event_id: bracket.event_id,
        bracket_id: bracket.id,
        best_of: 7,
        points_per_set: 11
      }

      assert {:ok, %Match{} = match} = Matches.create_match(scope, attrs)
      assert match.best_of == 7
      assert match.points_per_set == 11
    end
  end

  # ---------------------------------------------------------------------------
  # Groups: setup fields
  # ---------------------------------------------------------------------------

  describe "group setup" do
    test "create_group/2 with custom best_of and points_per_set" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)

      assert {:ok, %Group{} = group} =
               Matches.create_group(scope, %{
                 name: "Group A",
                 event_id: event.id,
                 best_of: 7,
                 points_per_set: 7
               })

      assert group.best_of == 7
      assert group.points_per_set == 7
    end

    test "create_group/2 uses default best_of and points_per_set" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)

      assert {:ok, %Group{} = group} =
               Matches.create_group(scope, %{name: "Group B", event_id: event.id})

      assert group.best_of == 5
      assert group.points_per_set == 11
    end

    test "update_group/3 updates best_of and points_per_set" do
      scope = Scope.for_user(insert(:superuser))
      group = insert(:group)

      assert {:ok, %Group{} = updated} =
               Matches.update_group(scope, group, %{best_of: 3, points_per_set: 7})

      assert updated.best_of == 3
      assert updated.points_per_set == 7
    end
  end

  # ---------------------------------------------------------------------------
  # Match Sets
  # ---------------------------------------------------------------------------

  describe "match_sets" do
    test "list_sets_for_match/1 returns sets ordered by set_number" do
      event = insert(:event)
      group = insert(:group, event: event)
      match = insert(:match, event: event, group: group)
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
      event = insert(:event)
      group = insert(:group, event: event)
      match = insert(:match, event: event, group: group)

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

    test "create_match_set/2 validates deuce for group match (11-point)" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      group = insert(:group, event: event, points_per_set: 11)
      match = insert(:match, event: event, group: group)

      # 11-10 is invalid (deuce reached, need 2-point lead)
      assert {:error, %Ecto.Changeset{} = changeset} =
               Matches.create_match_set(scope, %{
                 match_id: match.id,
                 set_number: 1,
                 score1: 11,
                 score2: 10
               })

      assert %{score1: [_]} = errors_on(changeset)
    end

    test "create_match_set/2 accepts valid deuce score for group match" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      group = insert(:group, event: event, points_per_set: 11)
      match = insert(:match, event: event, group: group)

      # 12-10 is valid (deuce, 2-point lead)
      assert {:ok, %MatchSet{}} =
               Matches.create_match_set(scope, %{
                 match_id: match.id,
                 set_number: 1,
                 score1: 12,
                 score2: 10
               })
    end

    test "create_match_set/2 rejects over-scoring outside deuce" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      group = insert(:group, event: event, points_per_set: 11)
      match = insert(:match, event: event, group: group)

      # 12-5 is invalid (no deuce, winner should stop at 11)
      assert {:error, %Ecto.Changeset{} = changeset} =
               Matches.create_match_set(scope, %{
                 match_id: match.id,
                 set_number: 1,
                 score1: 12,
                 score2: 5
               })

      assert %{score1: [_]} = errors_on(changeset)
    end

    test "create_match_set/2 validates deuce for bracket match (7-point)" do
      scope = Scope.for_user(insert(:superuser))
      bracket = insert(:bracket)

      match =
        insert(:match, event: bracket.event, bracket: bracket, group: nil, points_per_set: 7)

      # 7-6 is invalid (deuce, need 2-point lead)
      assert {:error, %Ecto.Changeset{} = changeset} =
               Matches.create_match_set(scope, %{
                 match_id: match.id,
                 set_number: 1,
                 score1: 7,
                 score2: 6
               })

      assert %{score1: [_]} = errors_on(changeset)
    end

    test "create_match_set/2 accepts valid score for bracket match (7-point)" do
      scope = Scope.for_user(insert(:superuser))
      bracket = insert(:bracket)

      match =
        insert(:match, event: bracket.event, bracket: bracket, group: nil, points_per_set: 7)

      # 7-3 is valid
      assert {:ok, %MatchSet{}} =
               Matches.create_match_set(scope, %{
                 match_id: match.id,
                 set_number: 1,
                 score1: 7,
                 score2: 3
               })
    end

    test "create_match_set/2 allows partial (in-progress) scores" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      group = insert(:group, event: event, points_per_set: 11)
      match = insert(:match, event: event, group: group)

      # 5-3 is a valid in-progress score
      assert {:ok, %MatchSet{}} =
               Matches.create_match_set(scope, %{
                 match_id: match.id,
                 set_number: 1,
                 score1: 5,
                 score2: 3
               })
    end

    test "update_match_set/3 updates scores" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      group = insert(:group, event: event)
      match = insert(:match, event: event, group: group)
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
      event = insert(:event)
      group = insert(:group, event: event)
      match = insert(:match, event: event, group: group)
      set = insert(:match_set, match: match, set_number: 1)

      Matches.delete_match(scope, match)

      assert_raise Ecto.NoResultsError, fn -> Matches.get_match_set!(set.id) end
    end

    test "get_match!/1 preloads sets" do
      event = insert(:event)
      group = insert(:group, event: event)
      match = insert(:match, event: event, group: group)
      insert(:match_set, match: match, set_number: 1, score1: 11, score2: 5)

      result = Matches.get_match!(match.id)
      assert length(result.sets) == 1
      assert hd(result.sets).set_number == 1
    end
  end
end
