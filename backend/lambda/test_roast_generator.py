"""Unit tests for roast_generator prompt building and matchup formatting."""

import sys
import os
import unittest

# Ensure the lambda directory is importable
sys.path.insert(0, os.path.dirname(__file__))

# Mock boto3 before importing roast_generator so the module-level client creation doesn't fail
from unittest.mock import MagicMock
sys.modules["boto3"] = MagicMock()

from roast_generator import (
    _build_prompt,
    _format_matchups_section,
    _format_playoff_bracket_section,
    _build_playoff_roasting_approach,
)


def _make_team(tid, name="Team A", owner="Owner"):
    return {
        "id": tid,
        "name": name,
        "owner": owner,
        "record": "5-3",
        "points_for": 900,
        "points_against": 850,
        "streak": "W2",
        "top_players": [{"name": "Player X", "position": "QB", "points": 20.0}],
    }


def _make_matchup(home_id="1", away_id="2", home_score=110.0, away_score=95.0):
    return {
        "home_team_id": home_id,
        "away_team_id": away_id,
        "home_score": home_score,
        "away_score": away_score,
        "home_players": [
            {"name": "Star QB", "position": "QB", "points": 30.0, "is_starter": True},
            {"name": "Bust WR", "position": "WR", "points": 2.1, "is_starter": True},
            {"name": "Bench RB", "position": "RB", "points": 0.0, "is_starter": False},
        ],
        "away_players": [
            {"name": "Solid RB", "position": "RB", "points": 18.5, "is_starter": True},
            {"name": "OK TE", "position": "TE", "points": 8.0, "is_starter": True},
        ],
    }


class TestFormatMatchupsSection(unittest.TestCase):

    def test_empty_matchups_returns_empty_string(self):
        result = _format_matchups_section([], [], None)
        self.assertEqual(result, "")

    def test_none_matchups_returns_empty_string(self):
        result = _format_matchups_section(None, [], None)
        self.assertEqual(result, "")

    def test_section_header_includes_week_number(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        matchup = _make_matchup("1", "2")
        result = _format_matchups_section([matchup], teams, 8)
        self.assertIn("WEEK 8'S MATCHUPS", result)

    def test_section_header_fallback_without_week(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        matchup = _make_matchup("1", "2")
        result = _format_matchups_section([matchup], teams, None)
        self.assertIn("THIS WEEK'S MATCHUPS", result)

    def test_team_names_and_scores_appear(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        matchup = _make_matchup("1", "2", 110.0, 95.0)
        result = _format_matchups_section([matchup], teams, 5)
        self.assertIn("Eagles (110.0) vs Bears (95.0)", result)

    def test_win_loss_labels(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        matchup = _make_matchup("1", "2", 110.0, 95.0)
        result = _format_matchups_section([matchup], teams, 5)
        self.assertIn("Eagles -- 110.0 pts (WIN)", result)
        self.assertIn("Bears -- 95.0 pts (LOSS)", result)

    def test_tie_labels(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        matchup = _make_matchup("1", "2", 100.0, 100.0)
        result = _format_matchups_section([matchup], teams, 5)
        self.assertIn("(TIE)", result)

    def test_starters_listed_with_stats(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        matchup = _make_matchup("1", "2")
        result = _format_matchups_section([matchup], teams, 5)
        self.assertIn("Star QB (QB): 30.0 pts", result)
        self.assertIn("Bust WR (WR): 2.1 pts", result)
        self.assertIn("Solid RB (RB): 18.5 pts", result)
        self.assertIn("OK TE (TE): 8.0 pts", result)

    def test_bench_players_excluded(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        matchup = _make_matchup("1", "2")
        result = _format_matchups_section([matchup], teams, 5)
        self.assertNotIn("Bench RB", result)

    def test_top_scorer_highlighted(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        matchup = _make_matchup("1", "2")
        result = _format_matchups_section([matchup], teams, 5)
        self.assertIn("Star QB (QB): 30.0 pts ⭐ TOP SCORER", result)

    def test_biggest_bust_highlighted(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        matchup = _make_matchup("1", "2")
        result = _format_matchups_section([matchup], teams, 5)
        self.assertIn("Bust WR (WR): 2.1 pts 💩 BIGGEST BUST", result)

    def test_unknown_team_id_uses_fallback_name(self):
        teams = [_make_team("1", "Eagles")]  # team 2 not in list
        matchup = _make_matchup("1", "99")
        result = _format_matchups_section([matchup], teams, 5)
        self.assertIn("Team 99", result)

    def test_no_starters_shows_fallback(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        matchup = {
            "home_team_id": "1", "away_team_id": "2",
            "home_score": 80.0, "away_score": 70.0,
            "home_players": [], "away_players": [],
        }
        result = _format_matchups_section([matchup], teams, 5)
        self.assertIn("No starter data available", result)


class TestBuildPromptMatchupIntegration(unittest.TestCase):

    def test_no_matchups_omits_matchup_section(self):
        teams = [_make_team("1", "Eagles")]
        prompt = _build_prompt(teams, {}, 4, matchups=[], all_teams=teams)
        self.assertNotIn("MATCHUPS", prompt)
        self.assertNotIn("breakout games", prompt)

    def test_none_matchups_omits_matchup_section(self):
        teams = [_make_team("1", "Eagles")]
        prompt = _build_prompt(teams, {}, 4, matchups=None, all_teams=teams)
        self.assertNotIn("MATCHUPS", prompt)

    def test_with_matchups_includes_section_and_requirements(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        matchup = _make_matchup("1", "2")
        prompt = _build_prompt(
            teams, {}, 4, matchups=[matchup], week_number=8, all_teams=teams,
        )
        self.assertIn("WEEK 8'S MATCHUPS", prompt)
        self.assertIn("Star QB (QB): 30.0 pts", prompt)
        self.assertIn("breakout games and busts BY NAME", prompt)
        self.assertIn("at least one specific player performance per roast", prompt)
        self.assertIn("lost despite having a high-scoring player", prompt)

    def test_legacy_prompt_structure_preserved_without_matchups(self):
        """Backward compatibility: prompt without matchups matches the original structure."""
        teams = [_make_team("1", "Eagles")]
        prompt = _build_prompt(teams, {}, 4, matchups=[], all_teams=teams)
        self.assertIn("=== ROASTING APPROACH ===", prompt)
        self.assertIn("=== REQUIREMENTS ===", prompt)
        self.assertIn("=== LEAGUE DATA ===", prompt)
        self.assertIn("=== OUTPUT FORMAT ===", prompt)
        self.assertIn("Eagles", prompt)


if __name__ == "__main__":
    unittest.main()


def _make_bracket_entry(team_id, seed=1, current_round=1, opponent_id=None,
                        is_eliminated=False, is_consolation=False, is_championship=False):
    return {
        "team_id": team_id,
        "seed": seed,
        "current_round": current_round,
        "opponent_team_id": opponent_id,
        "is_eliminated": is_eliminated,
        "is_consolation": is_consolation,
        "is_championship": is_championship,
    }


class TestFormatPlayoffBracketSection(unittest.TestCase):

    def test_empty_bracket_returns_empty_string(self):
        self.assertEqual(_format_playoff_bracket_section([], []), "")

    def test_none_bracket_returns_empty_string(self):
        self.assertEqual(_format_playoff_bracket_section(None, []), "")

    def test_championship_matchup_shown(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        bracket = [
            _make_bracket_entry("1", seed=1, opponent_id="2", is_championship=True),
            _make_bracket_entry("2", seed=2, opponent_id="1", is_championship=True),
        ]
        result = _format_playoff_bracket_section(bracket, teams)
        self.assertIn("CHAMPIONSHIP MATCHUP", result)
        self.assertIn("#1 Eagles vs Bears", result)
        self.assertIn("#2 Bears vs Eagles", result)

    def test_winners_bracket_shown(self):
        teams = [_make_team("3", "Lions"), _make_team("4", "Rams")]
        bracket = [
            _make_bracket_entry("3", seed=3, current_round=1, opponent_id="4"),
        ]
        result = _format_playoff_bracket_section(bracket, teams)
        self.assertIn("WINNERS BRACKET", result)
        self.assertIn("#3 Lions (Round 1) vs Rams", result)

    def test_eliminated_tag_shown(self):
        teams = [_make_team("5", "Jets")]
        bracket = [
            _make_bracket_entry("5", seed=5, is_eliminated=True, is_consolation=True),
        ]
        result = _format_playoff_bracket_section(bracket, teams)
        self.assertIn("[ELIMINATED]", result)

    def test_consolation_bracket_shown(self):
        teams = [_make_team("6", "Colts")]
        bracket = [
            _make_bracket_entry("6", seed=6, is_consolation=True),
        ]
        result = _format_playoff_bracket_section(bracket, teams)
        self.assertIn("CONSOLATION BRACKET", result)
        self.assertIn("#6 Colts", result)

    def test_unknown_team_uses_fallback(self):
        bracket = [_make_bracket_entry("99", seed=4, opponent_id="100")]
        result = _format_playoff_bracket_section(bracket, [])
        self.assertIn("Team 99", result)


class TestBuildPlayoffRoastingApproach(unittest.TestCase):

    def test_championship_contenders_section(self):
        teams = [_make_team("1", "Eagles"), _make_team("2", "Bears")]
        bracket = [
            _make_bracket_entry("1", seed=1, opponent_id="2", is_championship=True),
        ]
        result = _build_playoff_roasting_approach(bracket, teams)
        self.assertIn("CHAMPIONSHIP CONTENDERS", result)
        self.assertIn("Eagles", result)

    def test_eliminated_section(self):
        teams = [_make_team("5", "Jets")]
        bracket = [
            _make_bracket_entry("5", seed=5, is_eliminated=True),
        ]
        result = _build_playoff_roasting_approach(bracket, teams)
        self.assertIn("ELIMINATED", result)
        self.assertIn("Jets", result)

    def test_consolation_section(self):
        teams = [_make_team("6", "Colts")]
        bracket = [
            _make_bracket_entry("6", seed=6, is_consolation=True),
        ]
        result = _build_playoff_roasting_approach(bracket, teams)
        self.assertIn("CONSOLATION BRACKET", result)

    def test_active_bracket_section(self):
        teams = [_make_team("3", "Lions"), _make_team("4", "Rams")]
        bracket = [
            _make_bracket_entry("3", seed=3, opponent_id="4"),
        ]
        result = _build_playoff_roasting_approach(bracket, teams)
        self.assertIn("ACTIVE BRACKET", result)

    def test_playoff_mode_label(self):
        bracket = [_make_bracket_entry("1", seed=1)]
        result = _build_playoff_roasting_approach(bracket, [_make_team("1")])
        self.assertIn("PLAYOFF MODE", result)


class TestBuildPromptPlayoffMode(unittest.TestCase):
    """Tests for playoff prompt mode in _build_prompt (Req 6.1-6.6, 7.5)."""

    def _base_teams(self):
        return [
            _make_team("1", "Eagles", "Alice"),
            _make_team("2", "Bears", "Bob"),
            _make_team("3", "Lions", "Carol"),
            _make_team("4", "Rams", "Dave"),
        ]

    def _base_bracket(self):
        return [
            _make_bracket_entry("1", seed=1, opponent_id="2", is_championship=True),
            _make_bracket_entry("2", seed=2, opponent_id="1", is_championship=True),
            _make_bracket_entry("3", seed=3, is_consolation=True),
            _make_bracket_entry("4", seed=4, is_eliminated=True, is_consolation=True),
        ]

    def test_playoff_mode_activates_with_bracket(self):
        """Req 6.1: Playoff phase with bracket data shifts to playoff roasting approach."""
        teams = self._base_teams()
        bracket = self._base_bracket()
        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="playoffs", playoff_bracket=bracket, all_teams=teams,
        )
        self.assertIn("PLAYOFF MODE", prompt)
        self.assertNotIn("TOP TIER", prompt)
        self.assertNotIn("MIDDLE TIER", prompt)
        self.assertNotIn("BOTTOM TIER", prompt)

    def test_playoff_prompt_contains_elimination_language(self):
        """Req 6.1: Playoff prompt emphasizes elimination pressure."""
        teams = self._base_teams()
        bracket = self._base_bracket()
        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="playoffs", playoff_bracket=bracket, all_teams=teams,
        )
        self.assertIn("elimination", prompt.lower())

    def test_playoff_prompt_references_seeds(self):
        """Req 6.2: Playoff prompt references team seeds."""
        teams = self._base_teams()
        bracket = self._base_bracket()
        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="playoffs", playoff_bracket=bracket, all_teams=teams,
        )
        self.assertIn("#1", prompt)
        self.assertIn("#2", prompt)

    def test_playoff_prompt_mocks_eliminated(self):
        """Req 6.3: Eliminated teams are mocked with consolation reference."""
        teams = self._base_teams()
        bracket = self._base_bracket()
        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="playoffs", playoff_bracket=bracket, all_teams=teams,
        )
        self.assertIn("ELIMINATED", prompt)
        self.assertIn("CONSOLATION", prompt)

    def test_playoff_prompt_shows_championship_matchup(self):
        """Req 6.5: Championship matchup gets distinct treatment."""
        teams = self._base_teams()
        bracket = self._base_bracket()
        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="playoffs", playoff_bracket=bracket, all_teams=teams,
        )
        self.assertIn("CHAMPIONSHIP", prompt)
        self.assertIn("Eagles", prompt)
        self.assertIn("Bears", prompt)

    def test_playoff_prompt_includes_bracket_section(self):
        """Bracket data produces a PLAYOFF BRACKET section in the prompt."""
        teams = self._base_teams()
        bracket = self._base_bracket()
        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="playoffs", playoff_bracket=bracket, all_teams=teams,
        )
        self.assertIn("PLAYOFF BRACKET", prompt)

    def test_playoff_prompt_includes_playoff_requirements(self):
        """Playoff mode adds playoff-specific requirements to the prompt."""
        teams = self._base_teams()
        bracket = self._base_bracket()
        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="playoffs", playoff_bracket=bracket, all_teams=teams,
        )
        self.assertIn("playoff seed", prompt.lower())
        self.assertIn("elimination pressure", prompt.lower())

    def test_regular_season_no_playoff_content(self):
        """Req 6.6: Regular season prompt has no playoff references."""
        teams = self._base_teams()
        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="regular_season", all_teams=teams,
        )
        self.assertIn("TOP TIER", prompt)
        self.assertIn("MIDDLE TIER", prompt)
        self.assertIn("BOTTOM TIER", prompt)
        self.assertNotIn("PLAYOFF MODE", prompt)
        self.assertNotIn("PLAYOFF BRACKET", prompt)

    def test_playoffs_with_empty_bracket_falls_back(self):
        """Req 7.5: Playoffs with empty bracket falls back to regular-season format."""
        teams = self._base_teams()
        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="playoffs", playoff_bracket=[], all_teams=teams,
        )
        self.assertIn("TOP TIER", prompt)
        self.assertNotIn("PLAYOFF MODE", prompt)
        self.assertNotIn("PLAYOFF BRACKET", prompt)

    def test_playoffs_with_none_bracket_falls_back(self):
        """Req 7.5: Playoffs with None bracket falls back to regular-season format."""
        teams = self._base_teams()
        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="playoffs", playoff_bracket=None, all_teams=teams,
        )
        self.assertIn("TOP TIER", prompt)
        self.assertNotIn("PLAYOFF MODE", prompt)

    def test_playoff_mode_with_matchups_includes_both(self):
        """Playoff mode with matchup data includes both matchups and bracket."""
        teams = self._base_teams()
        bracket = self._base_bracket()
        matchup = _make_matchup("1", "2", 120.0, 105.0)
        prompt = _build_prompt(
            teams, {}, len(teams),
            matchups=[matchup], week_number=15,
            season_phase="playoffs", playoff_bracket=bracket, all_teams=teams,
        )
        self.assertIn("PLAYOFF MODE", prompt)
        self.assertIn("PLAYOFF BRACKET", prompt)
        self.assertIn("WEEK 15'S MATCHUPS", prompt)
        self.assertIn("Star QB", prompt)


if __name__ == "__main__":
    unittest.main()


# ---------------------------------------------------------------------------
# Property-based tests (hypothesis)
# ---------------------------------------------------------------------------
from hypothesis import given, settings, assume
from hypothesis.strategies import (
    composite,
    floats,
    integers,
    lists,
    text,
)

# Feature: roast-enhancements, Property 9: Prompt includes matchup and player data
# Validates: Requirements 4.1, 4.2, 4.3


@composite
def player_stats(draw, is_starter=True):
    """Generate a single player stat entry with a readable name and valid points."""
    # Use alpha names to avoid regex/formatting issues in prompt matching
    name = draw(text(alphabet="abcdefghijklmnopqrstuvwxyz", min_size=3, max_size=10))
    position = draw(text(alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZ", min_size=2, max_size=3))
    points = draw(floats(min_value=0.0, max_value=50.0, allow_nan=False, allow_infinity=False))
    return {
        "name": name,
        "position": position,
        "points": round(points, 1),
        "is_starter": is_starter,
    }


@composite
def matchup_with_teams(draw):
    """Generate a matchup with two teams, each having at least one starter.

    Returns (matchup_dict, home_team_dict, away_team_dict) so the caller can
    build the all_teams list and verify names/scores in the prompt.
    """
    home_id = str(draw(integers(min_value=1, max_value=999)))
    away_id = str(draw(integers(min_value=1, max_value=999)))
    assume(home_id != away_id)

    home_name = "Home" + draw(text(alphabet="abcdefghijklmnopqrstuvwxyz", min_size=2, max_size=8))
    away_name = "Away" + draw(text(alphabet="abcdefghijklmnopqrstuvwxyz", min_size=2, max_size=8))

    home_score = round(draw(floats(min_value=0.0, max_value=200.0, allow_nan=False, allow_infinity=False)), 1)
    away_score = round(draw(floats(min_value=0.0, max_value=200.0, allow_nan=False, allow_infinity=False)), 1)

    home_starters = draw(lists(player_stats(is_starter=True), min_size=1, max_size=5))
    away_starters = draw(lists(player_stats(is_starter=True), min_size=1, max_size=5))

    # Ensure unique names within each roster so top/bust identification is unambiguous
    seen = set()
    unique_home = []
    for p in home_starters:
        if p["name"] not in seen:
            seen.add(p["name"])
            unique_home.append(p)
    seen.clear()
    unique_away = []
    for p in away_starters:
        if p["name"] not in seen:
            seen.add(p["name"])
            unique_away.append(p)
    assume(len(unique_home) >= 1 and len(unique_away) >= 1)
    home_starters = unique_home
    away_starters = unique_away

    matchup = {
        "home_team_id": home_id,
        "away_team_id": away_id,
        "home_score": home_score,
        "away_score": away_score,
        "home_players": home_starters,
        "away_players": away_starters,
    }

    home_team = _make_team(home_id, home_name, "OwnerH")
    away_team = _make_team(away_id, away_name, "OwnerA")

    return matchup, home_team, away_team


class TestProperty9PromptIncludesMatchupData(unittest.TestCase):
    """Property 9: Prompt includes matchup and player data.

    For any non-empty list of WeeklyMatchup objects with at least one starter
    per team, the built prompt string should contain: each team's weekly score,
    each team's opponent name, every starter's name and point total, the name
    of the top-scoring player per team, and the name of the lowest-scoring
    starter per team.

    Validates: Requirements 4.1, 4.2, 4.3
    """

    @given(data=matchup_with_teams(), week=integers(min_value=1, max_value=18))
    @settings(max_examples=100)
    def test_prompt_contains_matchup_and_player_data(self, data, week):
        matchup, home_team, away_team = data
        all_teams = [home_team, away_team]

        # Ensure distinct point values within each roster so top/bust are unambiguous
        for side in ("home_players", "away_players"):
            pts = [p["points"] for p in matchup[side]]
            assume(len(pts) == len(set(pts)))

        # --- Test _format_matchups_section directly ---
        section = _format_matchups_section([matchup], all_teams, week)

        # 1. Each team's weekly score appears (formatted as .1f)
        self.assertIn(f"{matchup['home_score']:.1f}", section)
        self.assertIn(f"{matchup['away_score']:.1f}", section)

        # 2. Each team's opponent name appears
        self.assertIn(home_team["name"], section)
        self.assertIn(away_team["name"], section)

        # 3. Every starter's name and point total appear
        for side_key in ("home_players", "away_players"):
            for p in matchup[side_key]:
                self.assertIn(p["name"], section)
                self.assertIn(f"{p['points']:.1f} pts", section)

        # 4. Top scorer per team marked with ⭐ TOP SCORER
        for side_key in ("home_players", "away_players"):
            starters = matchup[side_key]
            top = max(starters, key=lambda p: p["points"])
            self.assertIn(f"{top['name']} ({top['position']}): {top['points']:.1f} pts ⭐ TOP SCORER", section)

        # 5. Lowest-scoring starter per team marked with 💩 BIGGEST BUST
        for side_key in ("home_players", "away_players"):
            starters = matchup[side_key]
            if len(starters) > 1:
                bust = min(starters, key=lambda p: p["points"])
                self.assertIn(f"{bust['name']} ({bust['position']}): {bust['points']:.1f} pts 💩 BIGGEST BUST", section)

        # --- Also verify _build_prompt includes the matchup section ---
        prompt = _build_prompt(
            all_teams, {}, len(all_teams),
            matchups=[matchup], week_number=week, all_teams=all_teams,
        )
        self.assertIn(f"WEEK {week}", prompt)
        self.assertIn(home_team["name"], prompt)
        self.assertIn(away_team["name"], prompt)


# Feature: roast-enhancements, Property 10: Empty matchups fall back to legacy prompt
# Validates: Requirements 4.6


@composite
def random_team(draw):
    """Generate a random valid team dict for property testing."""
    tid = str(draw(integers(min_value=1, max_value=999)))
    name = "Team" + draw(text(alphabet="abcdefghijklmnopqrstuvwxyz", min_size=2, max_size=8))
    owner = "Owner" + draw(text(alphabet="abcdefghijklmnopqrstuvwxyz", min_size=2, max_size=6))
    return _make_team(tid, name, owner)


from hypothesis.strategies import sampled_from, just


class TestProperty10EmptyMatchupsFallback(unittest.TestCase):
    """Property 10: Empty matchups fall back to legacy prompt.

    For any set of teams and context with an empty matchups list, the built
    prompt should not contain a "THIS WEEK'S MATCHUPS" section and should
    match the structure of the existing season-aggregate prompt format.

    Validates: Requirements 4.6
    """

    @given(
        teams=lists(random_team(), min_size=1, max_size=8),
        matchups_value=sampled_from([[], None]),
    )
    @settings(max_examples=100)
    def test_empty_matchups_produce_legacy_prompt(self, teams, matchups_value):
        # Deduplicate team IDs so _build_prompt gets a valid team list
        seen_ids = set()
        unique_teams = []
        for t in teams:
            if t["id"] not in seen_ids:
                seen_ids.add(t["id"])
                unique_teams.append(t)
        assume(len(unique_teams) >= 1)

        prompt = _build_prompt(
            unique_teams, {}, len(unique_teams),
            matchups=matchups_value,
        )

        # Must NOT contain matchup-specific sections or headers
        self.assertNotIn("THIS WEEK'S MATCHUPS", prompt)
        self.assertNotIn("breakout games and busts BY NAME", prompt)

        # Must contain legacy format sections
        self.assertIn("=== ROASTING APPROACH ===", prompt)
        self.assertIn("TOP TIER", prompt)
        self.assertIn("MIDDLE TIER", prompt)
        self.assertIn("BOTTOM TIER", prompt)
        self.assertIn("=== REQUIREMENTS ===", prompt)
        self.assertIn("=== LEAGUE DATA ===", prompt)
        self.assertIn("=== OUTPUT FORMAT ===", prompt)


# Feature: roast-enhancements, Property 14: Prompt content is phase-appropriate
# Validates: Requirements 6.1, 6.6


@composite
def team_list_with_bracket(draw):
    """Generate a list of unique teams and a valid playoff bracket referencing them.

    Returns (teams, bracket) where bracket has at least one entry per team.
    """
    count = draw(integers(min_value=2, max_value=8))
    teams = []
    seen_ids = set()
    for _ in range(count):
        t = draw(random_team())
        if t["id"] not in seen_ids:
            seen_ids.add(t["id"])
            teams.append(t)
    assume(len(teams) >= 2)

    # Build a bracket with at least one entry so playoff mode activates
    bracket = []
    ids = [t["id"] for t in teams]
    for i, tid in enumerate(ids):
        opp_id = ids[(i + 1) % len(ids)]
        bracket.append(
            _make_bracket_entry(
                tid,
                seed=i + 1,
                current_round=1,
                opponent_id=opp_id,
                is_championship=(i < 2),
            )
        )
    return teams, bracket


class TestProperty14PhaseAppropriatePrompt(unittest.TestCase):
    """Property 14: Prompt content is phase-appropriate.

    For any roast prompt built with a SeasonPhase value, when the phase is
    "playoffs" (with a non-empty bracket) the prompt should contain
    playoff-specific language, and when the phase is "regular_season" the
    prompt should not contain those playoff-specific terms.

    Validates: Requirements 6.1, 6.6
    """

    @given(data=team_list_with_bracket())
    @settings(max_examples=100)
    def test_playoff_phase_contains_playoff_language(self, data):
        teams, bracket = data

        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="playoffs",
            playoff_bracket=bracket,
            all_teams=teams,
        )
        prompt_lower = prompt.lower()

        assert "PLAYOFF MODE" in prompt, "Playoff prompt must contain 'PLAYOFF MODE'"
        assert "elimination" in prompt_lower, "Playoff prompt must mention elimination"
        assert "bracket" in prompt_lower, "Playoff prompt must mention bracket"

    @given(teams=lists(random_team(), min_size=1, max_size=8))
    @settings(max_examples=100)
    def test_regular_season_excludes_playoff_language(self, teams):
        # Deduplicate team IDs
        seen_ids = set()
        unique_teams = []
        for t in teams:
            if t["id"] not in seen_ids:
                seen_ids.add(t["id"])
                unique_teams.append(t)
        assume(len(unique_teams) >= 1)

        prompt = _build_prompt(
            unique_teams, {}, len(unique_teams),
            season_phase="regular_season",
            all_teams=unique_teams,
        )

        assert "PLAYOFF MODE" not in prompt, "Regular season prompt must not contain 'PLAYOFF MODE'"
        assert "TOP TIER" in prompt, "Regular season prompt must contain 'TOP TIER'"
        assert "MIDDLE TIER" in prompt, "Regular season prompt must contain 'MIDDLE TIER'"
        assert "BOTTOM TIER" in prompt, "Regular season prompt must contain 'BOTTOM TIER'"


# Feature: roast-enhancements, Property 15: Playoff bracket data appears in prompt
# Validates: Requirements 6.2, 6.3, 6.4, 6.5

from hypothesis.strategies import booleans


@composite
def bracket_with_varied_entries(draw):
    """Generate exactly 6 teams and a bracket with at least one championship,
    one eliminated/consolation, one consolation-only, and one active-with-opponent entry.

    Returns (teams, bracket) where every bracket entry references a valid team.
    """
    # Fixed 6 teams with unique IDs derived from a drawn offset to add variety
    base = draw(integers(min_value=1, max_value=500))
    ids = [str(base + i) for i in range(6)]
    teams = [_make_team(ids[i], f"Team{ids[i]}", f"Owner{i}") for i in range(6)]

    seed_pool = draw(lists(integers(min_value=1, max_value=8), min_size=6, max_size=6))

    bracket = [
        # Championship pair
        _make_bracket_entry(ids[0], seed=seed_pool[0], current_round=3,
                            opponent_id=ids[1], is_championship=True),
        _make_bracket_entry(ids[1], seed=seed_pool[1], current_round=3,
                            opponent_id=ids[0], is_championship=True),
        # Eliminated + consolation
        _make_bracket_entry(ids[2], seed=seed_pool[2], current_round=1,
                            is_eliminated=True, is_consolation=True),
        # Consolation only (not eliminated)
        _make_bracket_entry(ids[3], seed=seed_pool[3], current_round=1,
                            is_consolation=True),
        # Active winners bracket with opponent
        _make_bracket_entry(ids[4], seed=seed_pool[4], current_round=1,
                            opponent_id=ids[5]),
        # Another active entry
        _make_bracket_entry(ids[5], seed=seed_pool[5], current_round=1,
                            opponent_id=ids[4]),
    ]

    return teams, bracket


class TestProperty15PlayoffBracketDataInPrompt(unittest.TestCase):
    """Property 15: Playoff bracket data appears in prompt.

    For any non-empty list of PlayoffBracketEntry objects included in a
    playoff-phase prompt build, the prompt should: contain each team's seed
    number, reference eliminated teams' consolation status, mention
    head-to-head playoff pairings by both team names, and include
    championship-specific language for entries where isChampionship is true.

    Validates: Requirements 6.2, 6.3, 6.4, 6.5
    """

    @given(data=bracket_with_varied_entries())
    @settings(max_examples=100)
    def test_playoff_bracket_data_appears_in_prompt(self, data):
        teams, bracket = data
        team_names = {t["id"]: t["name"] for t in teams}

        # --- Test _format_playoff_bracket_section directly ---
        bracket_section = _format_playoff_bracket_section(bracket, teams)

        # Req 6.2: Each team's seed number appears as #N
        for entry in bracket:
            self.assertIn(f"#{entry['seed']}", bracket_section)

        # Req 6.3: Eliminated teams have [ELIMINATED] tag
        eliminated_entries = [e for e in bracket if e.get("is_eliminated")]
        for entry in eliminated_entries:
            name = team_names[entry["team_id"]]
            # The name and [ELIMINATED] should both appear in the section
            self.assertIn(name, bracket_section)
            self.assertIn("[ELIMINATED]", bracket_section)

        # Req 6.4: Head-to-head pairings show both team names
        for entry in bracket:
            opp_id = entry.get("opponent_team_id")
            if opp_id and opp_id in team_names:
                # Championship and winners bracket entries show "vs opponent"
                if entry.get("is_championship") or not entry.get("is_consolation"):
                    name = team_names[entry["team_id"]]
                    opp_name = team_names[opp_id]
                    self.assertIn(name, bracket_section)
                    self.assertIn(opp_name, bracket_section)

        # Req 6.5: Championship entries produce CHAMPIONSHIP language
        champ_entries = [e for e in bracket if e.get("is_championship")]
        if champ_entries:
            self.assertIn("CHAMPIONSHIP", bracket_section)

        # --- Test _build_playoff_roasting_approach directly ---
        approach = _build_playoff_roasting_approach(bracket, teams)

        # Championship team names appear in CHAMPIONSHIP CONTENDERS
        for entry in champ_entries:
            name = team_names[entry["team_id"]]
            self.assertIn(name, approach)
        if champ_entries:
            self.assertIn("CHAMPIONSHIP CONTENDERS", approach)

        # Eliminated team names appear in ELIMINATED section
        for entry in eliminated_entries:
            name = team_names[entry["team_id"]]
            self.assertIn(name, approach)

        # --- Test via _build_prompt with season_phase="playoffs" ---
        prompt = _build_prompt(
            teams, {}, len(teams),
            season_phase="playoffs",
            playoff_bracket=bracket,
            all_teams=teams,
        )

        # Bracket section is embedded in the full prompt
        self.assertIn("PLAYOFF BRACKET", prompt)
        self.assertIn("PLAYOFF MODE", prompt)
        self.assertIn("CHAMPIONSHIP", prompt)

        # Seeds appear in the full prompt
        for entry in bracket:
            self.assertIn(f"#{entry['seed']}", prompt)


# Feature: roast-enhancements, Property 18: Playoff bracket fallback
# Validates: Requirements 7.5


class TestProperty18PlayoffBracketFallback(unittest.TestCase):
    """Property 18: Playoff bracket fallback.

    For any roast prompt built with season_phase="playoffs" but a nil or empty
    playoff bracket, the prompt should fall back to the regular-season format
    and should not contain bracket-specific sections (seeds, elimination
    references).

    Validates: Requirements 7.5
    """

    @given(
        teams=lists(random_team(), min_size=1, max_size=8),
        bracket_value=sampled_from([[], None]),
    )
    @settings(max_examples=100)
    def test_playoff_with_empty_bracket_falls_back_to_regular_season(self, teams, bracket_value):
        # Deduplicate team IDs
        seen_ids = set()
        unique_teams = []
        for t in teams:
            if t["id"] not in seen_ids:
                seen_ids.add(t["id"])
                unique_teams.append(t)
        assume(len(unique_teams) >= 1)

        prompt = _build_prompt(
            unique_teams, {}, len(unique_teams),
            season_phase="playoffs",
            playoff_bracket=bracket_value,
            all_teams=unique_teams,
        )

        # Must NOT contain playoff-specific content
        assert "PLAYOFF MODE" not in prompt, "Fallback prompt must not contain 'PLAYOFF MODE'"
        assert "PLAYOFF BRACKET" not in prompt, "Fallback prompt must not contain 'PLAYOFF BRACKET'"
        assert "CHAMPIONSHIP MATCHUP" not in prompt, "Fallback prompt must not contain 'CHAMPIONSHIP MATCHUP'"
        assert "CHAMPIONSHIP CONTENDERS" not in prompt, "Fallback prompt must not contain 'CHAMPIONSHIP CONTENDERS'"
        assert "[ELIMINATED]" not in prompt, "Fallback prompt must not contain '[ELIMINATED]'"

        # Must contain regular-season format markers
        assert "=== ROASTING APPROACH ===" in prompt, "Fallback prompt must contain regular-season roasting approach"
        assert "TOP TIER" in prompt, "Fallback prompt must contain 'TOP TIER'"
        assert "MIDDLE TIER" in prompt, "Fallback prompt must contain 'MIDDLE TIER'"
        assert "BOTTOM TIER" in prompt, "Fallback prompt must contain 'BOTTOM TIER'"
