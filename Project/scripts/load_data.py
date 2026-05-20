import json
import os
import mysql.connector

# ===============================
# MySQL connection
# ===============================
conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="",
    database="cricket_wc"
)
cursor = conn.cursor()

# ===============================
# Caches
# ===============================
team_cache = {}
player_cache = {}
venue_cache = {}
format_cache = {}

# ===============================
# Helper functions
# ===============================
def get_or_create_format(name):
    if name in format_cache:
        return format_cache[name]
    cursor.execute("SELECT format_id FROM Format WHERE format_name=%s", (name,))
    row = cursor.fetchone()
    if row:
        format_cache[name] = row[0]
        return row[0]
    cursor.execute("INSERT INTO Format (format_name) VALUES (%s)", (name,))
    conn.commit()
    format_cache[name] = cursor.lastrowid
    return cursor.lastrowid


def get_or_create_team(name):
    if name in team_cache:
        return team_cache[name]
    cursor.execute("SELECT team_id FROM Team WHERE team_name=%s", (name,))
    row = cursor.fetchone()
    if row:
        team_cache[name] = row[0]
        return row[0]
    cursor.execute("INSERT INTO Team (team_name) VALUES (%s)", (name,))
    conn.commit()
    team_cache[name] = cursor.lastrowid
    return cursor.lastrowid


def get_or_create_player(name, team_id):
    key = (name, team_id)
    if key in player_cache:
        return player_cache[key]
    cursor.execute(
        "SELECT player_id FROM Player WHERE player_name=%s AND team_id=%s",
        (name, team_id)
    )
    row = cursor.fetchone()
    if row:
        player_cache[key] = row[0]
        return row[0]
    cursor.execute(
        "INSERT INTO Player (player_name, team_id) VALUES (%s,%s)",
        (name, team_id)
    )
    conn.commit()
    player_cache[key] = cursor.lastrowid
    return cursor.lastrowid


def get_or_create_venue(name, country):
    key = (name, country)
    if key in venue_cache:
        return venue_cache[key]
    cursor.execute(
        "SELECT venue_id FROM Venue WHERE venue_name=%s AND venue_country=%s",
        (name, country)
    )
    row = cursor.fetchone()
    if row:
        venue_cache[key] = row[0]
        return row[0]
    cursor.execute(
        "INSERT INTO Venue (venue_name, venue_country) VALUES (%s,%s)",
        (name, country)
    )
    conn.commit()
    venue_cache[key] = cursor.lastrowid
    return cursor.lastrowid


# ===============================
# Loader
# ===============================
BASE_DIR = "data"
total_matches = 0

for format_dir in ["ODI_WC", "T20_WC"]:
    format_name = "ODI" if format_dir == "ODI_WC" else "T20"
    format_id = get_or_create_format(format_name)
    print(f"\n📦 Loading format: {format_name}")

    format_path = os.path.join(BASE_DIR, format_dir)
    if not os.path.isdir(format_path):
        continue

    for year in sorted(os.listdir(format_path)):
        year_path = os.path.join(format_path, year)
        if not os.path.isdir(year_path):
            continue

        print(f"  📅 Year: {year}")

        files = [f for f in os.listdir(year_path) if f.endswith(".json")]
        print(f"    ➜ {len(files)} match files found")

        for idx, fname in enumerate(files, start=1):
            print(f"    🏏 [{idx}/{len(files)}] Loading {fname}")

            with open(os.path.join(year_path, fname), "r", encoding="utf-8") as f:
                data = json.load(f)

            info = data["info"]

            # Venue
            venue_id = get_or_create_venue(
                info.get("venue", "Unknown"),
                info.get("city", "Unknown")
            )

            # Match
            match_stage = info.get("event", {}).get("stage", "Group")
            match_date = info["dates"][0]
            winner = info.get("outcome", {}).get("winner")
            winner_team_id = get_or_create_team(winner) if winner else None
            result_type = info.get("outcome", {}).get("result")
            margin_runs = info.get("outcome", {}).get("by", {}).get("runs")
            margin_wickets = info.get("outcome", {}).get("by", {}).get("wickets")

            cursor.execute("""
                INSERT INTO `Match`
                (format_id, venue_id, match_stage, match_date,
                 winner_team_id, result_type, margin_runs, margin_wickets)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
            """, (
                format_id, venue_id, match_stage, match_date,
                winner_team_id, result_type, margin_runs, margin_wickets
            ))
            conn.commit()
            match_id = cursor.lastrowid
            total_matches += 1

            # Match teams
            for team in info["teams"]:
                team_id = get_or_create_team(team)
                cursor.execute(
                    "INSERT INTO MatchTeam (match_id, team_id) VALUES (%s,%s)",
                    (match_id, team_id)
                )
            conn.commit()

            # Players
            for team, players in info["players"].items():
                team_id = get_or_create_team(team)
                for p in players:
                    get_or_create_player(p, team_id)

            # Innings
            for inn_no, innings in enumerate(data["innings"], start=1):
                batting_team = innings["team"]
                batting_team_id = get_or_create_team(batting_team)

                cursor.execute(
                    "INSERT INTO Innings (match_id, batting_team_id, innings_number) VALUES (%s,%s,%s)",
                    (match_id, batting_team_id, inn_no)
                )
                conn.commit()
                innings_id = cursor.lastrowid

                bowling_team = [t for t in info["teams"] if t != batting_team][0]
                bowling_team_id = get_or_create_team(bowling_team)

                for over in innings["overs"]:
                    over_no = over["over"]
                    ball_no = 1

                    for d in over["deliveries"]:
                        striker_id = get_or_create_player(d["batter"], batting_team_id)
                        non_striker_id = get_or_create_player(d["non_striker"], batting_team_id)
                        bowler_id = get_or_create_player(d["bowler"], bowling_team_id)

                        cursor.execute("""
                            INSERT INTO Delivery
                            (innings_id, over_number, ball_number,
                             bowler_id, striker_id, non_striker_id,
                             runs_batsman, runs_total)
                            VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                        """, (
                            innings_id, over_no, ball_no,
                            bowler_id, striker_id, non_striker_id,
                            d["runs"]["batter"],
                            d["runs"]["total"]
                        ))
                        conn.commit()
                        delivery_id = cursor.lastrowid
                        ball_no += 1

                        # Extras
                        for etype, eruns in d.get("extras", {}).items():
                            cursor.execute(
                                "INSERT INTO DeliveryExtra (delivery_id, extra_type, extra_runs) VALUES (%s,%s,%s)",
                                (delivery_id, etype, eruns)
                            )
                        conn.commit()

                        # Wickets
                        for w in d.get("wickets", []):
                            dismissed_id = get_or_create_player(
                                w["player_out"], batting_team_id
                            )
                            cursor.execute(
                                "INSERT INTO Wicket (delivery_id, dismissed_player_id, dismissal_type) VALUES (%s,%s,%s)",
                                (delivery_id, dismissed_id, w["kind"])
                            )
                            conn.commit()
                            wicket_id = cursor.lastrowid

                            for f in w.get("fielders", []):
                                f_id = get_or_create_player(f["name"], bowling_team_id)
                                cursor.execute(
                                    "INSERT INTO FieldingEvent (wicket_id, fielder_id, event_type) VALUES (%s,%s,%s)",
                                    (wicket_id, f_id, f.get("kind", w["kind"]))
                                )
                            conn.commit()

print(f"\n✅ DATA LOADING COMPLETE — {total_matches} matches loaded")
cursor.close()
conn.close()
