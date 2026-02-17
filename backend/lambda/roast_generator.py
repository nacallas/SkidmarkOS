"""Skidmark roast generator Lambda. Calls Bedrock Claude to produce fantasy football roasts."""

import json
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

import boto3

bedrock = boto3.client(
    "bedrock-runtime",
    region_name=os.environ.get("BEDROCK_REGION", "us-east-1"),
)
MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")
BATCH_SIZE = 2


def handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
        teams = body.get("teams", [])
        ctx = body.get("context", {})

        if not teams:
            return _response(400, {"error": "No teams provided"})

        # Parse expanded request fields (backward-compatible: all optional)
        matchups = body.get("matchups", [])
        week_number = body.get("week_number")
        season_phase = body.get("season_phase", "regular_season")
        playoff_bracket = body.get("playoff_bracket")

        roasts = _generate_roasts_parallel(
            teams, ctx, matchups, week_number, season_phase, playoff_bracket
        )
        return _response(200, {"roasts": roasts})

    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON body"})
    except Exception as e:
        print(f"Error: {e}")
        return _response(500, {"error": "Failed to generate roasts"})


def _generate_roasts_parallel(
    teams: list,
    ctx: dict,
    matchups: list,
    week_number: int | None,
    season_phase: str,
    playoff_bracket: list | None,
) -> dict:
    """Split teams into batches and invoke Bedrock in parallel, then merge results."""
    batches = [teams[i:i + BATCH_SIZE] for i in range(0, len(teams), BATCH_SIZE)]

    if len(batches) == 1:
        prompt = _build_prompt(
            batches[0], ctx, len(teams), matchups, week_number, season_phase,
            playoff_bracket, all_teams=teams,
        )
        return _call_bedrock(prompt)

    merged = {}
    with ThreadPoolExecutor(max_workers=len(batches)) as executor:
        futures = {
            executor.submit(
                _call_bedrock,
                _build_prompt(
                    batch, ctx, len(teams), matchups, week_number, season_phase,
                    playoff_bracket, all_teams=teams,
                ),
            ): batch
            for batch in batches
        }
        for future in as_completed(futures):
            merged.update(future.result())
    return merged


def _format_matchups_section(matchups: list, all_teams: list, week_number: int | None) -> str:
    """Build the THIS WEEK'S MATCHUPS prompt section from matchup data.

    For each matchup, shows the head-to-head result with scores, lists all
    starters with their stat lines, and highlights the top scorer and biggest
    bust per team.
    """
    if not matchups:
        return ""

    team_names = {str(t["id"]): t.get("name", f"Team {t['id']}") for t in all_teams}
    week_label = f"WEEK {week_number}" if week_number else "THIS WEEK"

    lines = [f"=== {week_label}'S MATCHUPS ===\n"]

    for m in matchups:
        home_id = str(m.get("home_team_id", ""))
        away_id = str(m.get("away_team_id", ""))
        home_name = team_names.get(home_id, f"Team {home_id}")
        away_name = team_names.get(away_id, f"Team {away_id}")
        home_score = m.get("home_score", 0)
        away_score = m.get("away_score", 0)

        if home_score > away_score:
            result_home, result_away = "WIN", "LOSS"
        elif away_score > home_score:
            result_home, result_away = "LOSS", "WIN"
        else:
            result_home, result_away = "TIE", "TIE"

        lines.append(f"{home_name} ({home_score:.1f}) vs {away_name} ({away_score:.1f})")
        lines.append("")

        for team_name, score, result, players_key in [
            (home_name, home_score, result_home, "home_players"),
            (away_name, away_score, result_away, "away_players"),
        ]:
            players = m.get(players_key, [])
            starters = [p for p in players if p.get("is_starter", False)]

            lines.append(f"  {team_name} -- {score:.1f} pts ({result})")

            if starters:
                top = max(starters, key=lambda p: p.get("points", 0))
                bust = min(starters, key=lambda p: p.get("points", 0))

                for p in starters:
                    name = p.get("name", "Unknown")
                    pos = p.get("position", "??")
                    pts = p.get("points", 0)
                    marker = ""
                    if p is top:
                        marker = " ⭐ TOP SCORER"
                    elif p is bust:
                        marker = " 💩 BIGGEST BUST"
                    lines.append(f"    {name} ({pos}): {pts:.1f} pts{marker}")
            else:
                lines.append("    No starter data available")

            lines.append("")

        lines.append("---")

    return "\n".join(lines)

def _format_playoff_bracket_section(playoff_bracket: list, all_teams: list) -> str:
    """Build the PLAYOFF BRACKET prompt section from bracket data.

    Shows seeds, matchup pairings, elimination status, and championship info
    for each team in the bracket.
    """
    if not playoff_bracket:
        return ""

    team_names = {str(t["id"]): t.get("name", f"Team {t['id']}") for t in all_teams}

    lines = ["=== PLAYOFF BRACKET ===\n"]

    # Group entries by bracket type
    championship = [e for e in playoff_bracket if e.get("is_championship", False)]
    winners = [e for e in playoff_bracket if not e.get("is_consolation", False) and not e.get("is_championship", False)]
    consolation = [e for e in playoff_bracket if e.get("is_consolation", False)]

    if championship:
        lines.append("🏆 CHAMPIONSHIP MATCHUP:")
        for entry in championship:
            tid = str(entry.get("team_id", ""))
            name = team_names.get(tid, f"Team {tid}")
            seed = entry.get("seed", "?")
            opp_id = str(entry.get("opponent_team_id", ""))
            opp_name = team_names.get(opp_id, f"Team {opp_id}") if opp_id else "TBD"
            lines.append(f"  #{seed} {name} vs {opp_name}")
        lines.append("")

    if winners:
        lines.append("WINNERS BRACKET:")
        for entry in winners:
            tid = str(entry.get("team_id", ""))
            name = team_names.get(tid, f"Team {tid}")
            seed = entry.get("seed", "?")
            rnd = entry.get("current_round", "?")
            opp_id = str(entry.get("opponent_team_id", ""))
            opp_name = team_names.get(opp_id, f"Team {opp_id}") if opp_id else "TBD"
            eliminated = " [ELIMINATED]" if entry.get("is_eliminated", False) else ""
            lines.append(f"  #{seed} {name} (Round {rnd}) vs {opp_name}{eliminated}")
        lines.append("")

    if consolation:
        lines.append("CONSOLATION BRACKET (the losers' lounge):")
        for entry in consolation:
            tid = str(entry.get("team_id", ""))
            name = team_names.get(tid, f"Team {tid}")
            seed = entry.get("seed", "?")
            eliminated = " [ELIMINATED]" if entry.get("is_eliminated", False) else ""
            lines.append(f"  #{seed} {name}{eliminated}")
        lines.append("")

    return "\n".join(lines)

def _build_playoff_roasting_approach(playoff_bracket: list, all_teams: list) -> str:
    """Build the playoff-specific ROASTING APPROACH section.

    Replaces the regular-season TOP/MIDDLE/BOTTOM tier structure with
    playoff tiers: championship contenders, active bracket teams, and
    eliminated/consolation teams.
    """
    team_names = {str(t["id"]): t.get("name", f"Team {t['id']}") for t in all_teams}

    champ_teams = [e for e in playoff_bracket if e.get("is_championship", False)]
    eliminated = [e for e in playoff_bracket if e.get("is_eliminated", False)]
    consolation = [e for e in playoff_bracket if e.get("is_consolation", False) and not e.get("is_eliminated", False)]
    active = [
        e for e in playoff_bracket
        if not e.get("is_championship", False)
        and not e.get("is_eliminated", False)
        and not e.get("is_consolation", False)
    ]

    champ_names = ", ".join(
        team_names.get(str(e.get("team_id", "")), "Unknown") for e in champ_teams
    )
    eliminated_names = ", ".join(
        team_names.get(str(e.get("team_id", "")), "Unknown") for e in eliminated
    )

    lines = [
        "=== ROASTING APPROACH (PLAYOFF MODE) ===",
        "",
        "This is the PLAYOFFS. Every game is win-or-go-home. The stakes are real, "
        "the pressure is crushing, and the roasts should match the intensity.",
        "",
    ]

    if champ_teams:
        lines.append(
            f"🏆 CHAMPIONSHIP CONTENDERS ({champ_names}): These teams are playing for "
            "the title and their legacy. Roast them like legends on trial -- acknowledge "
            "they made it this far, then question whether they deserve it. Reference their "
            "seed, their bracket path, and why their opponent might end their dream."
        )
        lines.append("")

    if active:
        lines.append(
            "ACTIVE BRACKET: Still alive but one bad week from elimination. Mock their "
            "playoff seed, their matchup, and the pressure of knowing it could all end. "
            "Reference their opponent and what a loss would mean."
        )
        lines.append("")

    if consolation:
        lines.append(
            "CONSOLATION BRACKET: Already out of title contention but still playing "
            "meaningless games. Mock the futility of consolation playoff wins. "
            "They are playing for pride that does not exist."
        )
        lines.append("")

    if eliminated:
        lines.append(
            f"ELIMINATED ({eliminated_names}): Absolute destruction. Their season is OVER. "
            "They are watching from the couch while others compete for glory. "
            "Reference their seed, how far they fell, and the shame of early elimination."
        )
        lines.append("")

    return "\n".join(lines)




def _build_prompt(
    teams: list,
    ctx: dict,
    total_teams: int,
    matchups: list | None = None,
    week_number: int | None = None,
    season_phase: str = "regular_season",
    playoff_bracket: list | None = None,
    all_teams: list | None = None,
) -> str:
    """Assemble the Claude prompt from team data and league context.

    When matchups are provided, includes a THIS WEEK'S MATCHUPS section with
    per-team scores, starter stat lines, top scorer and biggest bust highlights.
    When matchups are absent or empty, the existing season-aggregate format is
    preserved for backward compatibility.
    """

    # Format each team into a readable block
    team_blocks = []
    for t in teams:
        players = ", ".join(
            f"{p['name']} ({p['position']}, {p['points']} pts)"
            for p in t.get("top_players", [])
        )
        team_blocks.append(
            f"- ID: {t['id']} | \"{t['name']}\" owned by {t['owner']}\n"
            f"  Record: {t['record']} | PF: {t.get('points_for', '?')} | "
            f"PA: {t.get('points_against', '?')} | Streak: {t.get('streak', '?')}\n"
            f"  Top players: {players or 'none listed'}"
        )
    teams_text = "\n".join(team_blocks)

    # Format league context
    jokes = ctx.get("inside_jokes", [])
    jokes_text = "\n".join(
        f"- \"{j['term']}\": {j['explanation']}" for j in jokes
    ) if jokes else "None provided."

    personalities = ctx.get("personalities", [])
    personalities_text = "\n".join(
        f"- {p['player_name']}: {p['description']}" for p in personalities
    ) if personalities else "None provided."

    sacko = ctx.get("sacko_punishment", "not specified")
    culture = ctx.get("culture_notes", "not specified")

    team_ids = [t["id"] for t in teams]
    id_list = ", ".join(f'"{tid}"' for tid in team_ids)

    top_cutoff = 3
    mid_cutoff = min(7, total_teams - 1)

    # Build matchups section when data is available
    resolve_teams = all_teams if all_teams else teams
    matchups_section = ""
    if matchups:
        matchups_section = _format_matchups_section(matchups, resolve_teams, week_number)

    # Player-performance requirements when matchup data is present
    matchup_requirements = ""
    if matchups:
        matchup_requirements = (
            "- Reference specific player performances from this week's matchups. "
            "Call out breakout games and busts BY NAME.\n"
            "- Mention at least one specific player performance per roast -- "
            "use their actual point totals.\n"
            "- Mock teams that lost despite having a high-scoring player on their roster. "
            "Mock teams that won despite having a bust starter."
        )

    # Determine whether to use playoff mode: requires playoffs phase AND bracket data.
    # Per Requirement 7.5, fall back to regular-season format when bracket is nil/empty.
    is_playoff_mode = season_phase == "playoffs" and bool(playoff_bracket)
    is_offseason = season_phase == "offseason"

    if is_playoff_mode:
        roasting_approach = _build_playoff_roasting_approach(playoff_bracket, resolve_teams)
        bracket_section = _format_playoff_bracket_section(playoff_bracket, resolve_teams)
        playoff_requirements = (
            "- Reference each team's playoff seed and bracket position.\n"
            "- Emphasize elimination pressure -- every loss could be the last.\n"
            "- Mock eliminated teams mercilessly and reference their consolation bracket exile.\n"
            "- For head-to-head playoff matchups, reference what is at stake.\n"
            "- Give championship matchup teams an elevated, legacy-defining roast treatment."
        )
    elif is_offseason:
        roasting_approach = f"""=== ROASTING APPROACH (OFFSEASON MODE) ===

The season is OVER. These are the final standings. Every win, every loss, every embarrassing stat line is now permanently etched in league history. There are no more chances to redeem a garbage season or prove the doubters wrong.

TOP TIER (ranks 1-{top_cutoff}): They won when it mattered. But did they REALLY earn it, or did they get carried by one lucky draft pick? Question their legacy. Were they actually good, or was everyone else just worse?

MIDDLE TIER (ranks {top_cutoff + 1}-{mid_cutoff}): The most forgettable teams in league history. Not good enough to celebrate, not bad enough to be memorable. They existed. That's about it.

BOTTOM TIER (ranks {mid_cutoff + 1}+): Their season was a disaster from start to finish. {f'The sacko punishment ({sacko}) awaits -- describe their impending humiliation in vivid detail.' if sacko != 'not specified' else 'They have nothing to show for an entire season of effort.'}"""
        bracket_section = ""
        playoff_requirements = ""
    else:
        roasting_approach = f"""=== ROASTING APPROACH ===

TOP TIER (ranks 1-{top_cutoff}): Celebrate success with backhanded compliments. Find the crack -- luck-carried records, boneheaded decisions, fraudulent point differentials -- and stick your finger in it.

MIDDLE TIER (ranks {top_cutoff + 1}-{mid_cutoff}): These are the frauds and pretenders. Mock their inconsistency and mediocrity ruthlessly. Not good enough to celebrate, not bad enough to pity.

BOTTOM TIER (ranks {mid_cutoff + 1}+): Absolute destruction. Reference their actual terrible stats. Mock delusional optimism. {f'The sacko punishment ({sacko}) is looming -- remind them VIVIDLY.' if sacko != 'not specified' else 'They are not tanking, they are just bad.'}"""
        bracket_section = ""
        playoff_requirements = ""

    # Combine all requirements
    all_extra_requirements = "\n".join(
        r for r in [matchup_requirements, playoff_requirements] if r
    )

    return f"""You are Skidmark -- the most vulgar, profane, brutally honest fantasy football roast bot ever created. Swearing is your native language: "fucking," "shit," "ass," "goddamn" and creative compound insults flow in every roast. You call out poor performances with zero sugarcoating. You are roasting FRIENDS -- the goal is laughs so hard they screenshot it for the group chat, not cruelty without comedic payoff.

{roasting_approach}

{matchups_section}{bracket_section}=== REQUIREMENTS ===

- Every stat, score, and record you reference MUST be exactly correct from the data provided. Use real numbers to twist the knife.
- Weave inside jokes and personality descriptions naturally into roasts -- these are GOLD. Generic insults are forgettable; personal references hit different. Only include inside jokes if you are confident it will make sense to the recipient and there is inside joke content loaded. 
- Write exactly 3-5 punchy sentences per team. No filler, no warm-up intros. Every sentence hits.
- Reference at least one actual statistic per roast.
- Use vivid metaphors, pop culture references, dark humor, and absurd comparisons.
{all_extra_requirements}

=== LEAGUE DATA ===

TEAMS (ranked by standing):
{teams_text}

INSIDE JOKES:
{jokes_text}

OWNER PERSONALITIES:
{personalities_text}

SACKO PUNISHMENT: {sacko}
LEAGUE CULTURE: {culture}

=== OUTPUT FORMAT ===

Return ONLY valid JSON (no markdown, no code fences). Each key is the team ID string, each value is the roast text (3-5 sentences).
Keys for this batch: {id_list}

Example: {{"1": "roast text here", "2": "roast text here"}}

Now channel your inner Skidmark. Be vulgar. Be brutal. Be statistically accurate. Be fucking hilarious. Go."""


def _call_bedrock(prompt: str) -> dict:
    """Invoke Bedrock Claude and parse the roasts JSON from the response."""

    response = bedrock.invoke_model(
        modelId=MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2048,
            "temperature": 0.9,
            "messages": [{"role": "user", "content": prompt}],
        }),
    )

    result = json.loads(response["body"].read())
    text = result["content"][0]["text"]

    # Strip markdown fences if Claude wraps the JSON anyway
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else text[3:]
        if text.endswith("```"):
            text = text[:-3]
        text = text.strip()

    return json.loads(text)


def _response(status: int, body: dict) -> dict:
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
