import json
import random
import time

import pandas as pd
import requests
from pandas.io.parsers.readers import read_csv

PAGE = 200

random.seed(42)

REGIONID_TO_STRING = {
    "ypl25l47": "BRA / PAL",
    "mol4z19n": "CHN / PAL",
    "e6lxy1dz": "EUR / PAL",
    "o316x197": "JPN / NTSC",
    "p2g50lnk": "KOR / NTSC",
    "pr184lqn": "USA / NTSC",
}


def get_games_with_regions(debug=False, save=False):
    pages = 0

    frames = []
    while True:
        offset = pages * PAGE
        url = f"https://www.speedrun.com/api/v1/games?max={PAGE}&offset={offset}"
        # url = (
        #     f"https://www.speedrun.com/api/v1/runs?max={page}&offset={offset}?game=nj1ne1p4"
        # )

        response = requests.get(url)
        parsed = json.loads(response.text)
        if "data" in parsed:
            parsed = parsed["data"]
        else:
            break

        for p in parsed:
            if len(p["regions"]) == 0:
                continue

            dfg = pd.json_normalize(p)
            dfg = dfg[["id", "names.international", "regions"]]

            dfg = (
                dfg.explode("regions").dropna(subset=["regions"]).reset_index(drop=True)
            )

            dfg = dfg.rename(
                columns={
                    "id": "GID",
                    "names.international": "gameName",
                    "regions": "REGIONID",
                }
            )

            for j, x in enumerate(dfg["REGIONID"]):
                regid = dfg["REGIONID"].iloc[j]
                dfg.at[j, "regionName"] = REGIONID_TO_STRING[regid]

            dfg = dfg.drop(["REGIONID"], axis=1)

            frames.append(dfg)
            print(dfg)

        pages += 1

    res = pd.concat(frames)

    if save:
        res.to_csv("allgame.csv", index=False)

    if debug:
        print(res.head())

    return res


# get_games_with_regions(save=True)


def get_regions(debug=False, save=False):
    url = f"https://www.speedrun.com/api/v1/regions"

    response = requests.get(url)
    parsed = json.loads(response.text)
    parsed = parsed["data"]

    dfr = pd.json_normalize(parsed)
    dfr = dfr[["id", "name"]]
    dfr = dfr.rename(
        columns={
            "id": "REGIONID",
            "name": "regionName",
        }
    )

    if debug:
        print(dfr)

    if save:
        dfr.to_csv("region234.csv", index=False)

    return dfr


# get_regions(debug=True, save=False)


def get_all_runtypes(df_runtypes: pd.DataFrame, save=False):
    frames = []
    wrong = set()

    run_types = set()
    count = 0
    for rt in set(df_runtypes.RUNTYPEID.values):
        print(rt)
        url = f"https://www.speedrun.com/api/v1/categories/{rt}"

        response = requests.get(url)
        parsed = json.loads(response.text)
        # print(parsed)
        if "data" in parsed:
            parsed = parsed["data"]

        rep = 30
        while "data" not in parsed:
            response = requests.get(url)
            parsed = json.loads(response.text)

            time.sleep(0.5)
            rep -= 1

            if rep <= 0:
                break

            if "data" in parsed:
                parsed = parsed["data"]
                break

        if rep <= 0:
            continue

        dfr = pd.json_normalize(parsed)
        dfr = dfr[["id", "name"]]
        dfr = dfr.rename(
            columns={
                "id": "RUNTYPEID",
                "name": "runTypeName",
            }
        )

        run_types.add(dfr["RUNTYPEID"].iloc[0])

        frames.append(dfr)
        print(dfr)
        count += 1
        print(f"{count} / {len(set(df_runtypes.RUNTYPEID.values))}")

    res = pd.concat(frames)
    print(wrong)

    if save:
        res.to_csv("runtypeswithname.csv", index=False)

    return res, run_types


def combine_run_types():
    df_runtypes = read_csv("runtypes.csv")
    df_runtypes = df_runtypes[["RUNTYPEID"]]

    res = read_csv("runtypeswithname.csv")

    res.merge(df_runtypes, on="RUNTYPEID")

    print(res)

    res.to_csv("filteredruntypes.csv", index=False)


def combine_runs_with_runtypes():
    df_runtypes = read_csv("filteredruntypes.csv")
    df_runtypes = df_runtypes[["RUNTYPEID"]]

    df_runs = read_csv("allruns.csv")

    df = df_runs.merge(df_runtypes, on="RUNTYPEID")
    print(df)

    df.to_csv("filteredruns.csv", index=False)


def get_all_users_info(df_users: pd.DataFrame, save=False):
    frames = []
    for user in set(df_users.PID.values):
        url = f"https://www.speedrun.com/api/v1/users/{user}"

        parsed = ""

        rep = 100
        while "data" not in parsed:
            response = requests.get(url)
            parsed = json.loads(response.text)

            time.sleep(0.5)
            rep -= 1

            if rep <= 0:
                break

            if "data" in parsed:
                parsed = parsed["data"]
                break

        if rep <= 0:
            print(f"{user=}")
            continue

        # print(json.dumps(parsed, indent=2))
        dfr = pd.json_normalize(parsed)

        if "location.country.code" not in dfr:
            print("FAILED HERE")
            print(dfr)
            continue

        dfr = dfr[["id", "names.international", "location.country.code"]]
        dfr = dfr.rename(
            columns={
                "id": "PID",
                "names.international": "userName",
                "location.country.code": "CID",
            }
        )

        frames.append(dfr)
        print(f"{len(frames)} / {len(set(df_users.PID.values))}")

    res = pd.concat(frames)
    if save:
        res.to_csv("userswithstuff.csv", index=False)

    return res


def another_filter_users():
    df_users = read_csv("allruns.csv")
    df_pid = df_users[["PID"]]
    df_eids = df_users[["EID"]]

    df_eids = df_eids.rename(
        columns={
            "EID": "PID",
        }
    )

    # df = df_eids.merge(df_pid, on="PID")

    df = pd.concat([df_eids, df_pid])

    get_all_users_info(df, save=True)


# another_filter_users()


def filter_runtypes():
    df_rt = read_csv("allruns.csv")
    df_rt = df_rt[["RUNTYPEID"]]

    get_all_runtypes(df_rt, save=True)


# filter_runtypes()


def get_all_runs(df_games: pd.DataFrame, debug=False, save=False):
    frames = []

    nr_failed = 0
    users = set()
    runids = set()
    runtypeids = set()

    gameids = set()

    games_added = 0

    for game in set(df_games.gid.values):
        print(game)
        if len(gameids) >= 250:
            break

        print("gameids len: ", len(gameids))

        runs_succ = 0
        url = f"https://www.speedrun.com/api/v1/runs?game={game}&max=150&status=verified&orderby=verify-date&direction=desc"

        response = requests.get(url)
        parsed = json.loads(response.text)
        if "data" in parsed and "pagination" in parsed:
            sz = parsed["pagination"]["size"]
            # the game is not popular enough
            if sz < 150:
                continue
        # print(sz)

        if "data" in parsed:
            parsed = parsed["data"]
        else:
            continue

        rframes = []
        for p in parsed:
            if p["date"] is None:
                nr_failed += 1
                continue

            if p["status"] is None:
                nr_failed += 1
                continue

            if "examiner" not in p["status"]:
                nr_failed += 1
                continue

            if "region" not in p["system"] or p["system"]["region"] is None:
                nr_failed += 1
                continue

            dfg = pd.json_normalize(p)

            if len(dfg["players"].iloc[0]) != 1:
                nr_failed += 1
                continue

            if dfg["players"].iloc[0][0]["rel"] != "user":
                nr_failed += 1
                continue

            print(f"{nr_failed=}")

            id = dfg["players"].iloc[0][0]["id"]
            regid = dfg["system.region"].iloc[0]

            dfg = dfg[
                [
                    "id",
                    "category",
                    "game",
                    "times.primary_t",
                    "date",
                    # "system.region",
                    "system.emulated",
                    "status.examiner",
                ]
            ]

            dfg = dfg.rename(
                columns={
                    "id": "RUNID",
                    "category": "RUNTYPEID",
                    "game": "GID",
                    "date": "submissionDate",
                    "times.primary_t": "duration",
                    "system.emulated": "isEmulated",
                    "status.examiner": "EID",
                    # "regions": "REGIONID",
                }
            )

            eid = dfg["EID"].iloc[0]

            runtypeid = dfg["RUNTYPEID"].iloc[0]
            runtypeids.add(runtypeid)

            dfg.at[0, "regionName"] = REGIONID_TO_STRING[regid]

            runid = dfg["RUNID"].iloc[0]
            if runid in runids:
                continue
            runids.add(runid)

            dfg.at[0, "PID"] = id

            flag = False
            for uid in (id, eid):
                url_users = f"https://www.speedrun.com/api/v1/users/{uid}"

                response_users = requests.get(url_users)
                parsed_users = json.loads(response_users.text)
                if "data" not in parsed_users:
                    flag = True
                    continue
                parsed_users = parsed_users["data"]

                dfr_u2 = pd.json_normalize(parsed_users)
                if "location.country.code" not in dfr_u2:
                    flag = True
                    continue
                users.add(uid)

            if flag:
                continue

            url_cat = f"https://www.speedrun.com/api/v1/categories/{runtypeid}"

            response_cat = requests.get(url_cat)
            parsed_cat = json.loads(response_cat.text)
            if "data" not in parsed_cat:
                continue

            rframes.append(dfg)
            print(dfg)

            gid = dfg["GID"].iloc[0]
            runs_succ += 1

        if runs_succ >= 50:
            for f in rframes:
                frames.append(f)
            gameids.add(gid)
            games_added += 1
            print(f"{games_added=} out of 250")

        print(f"runs succ: {runs_succ=} out of 150")
        time.sleep(0.01)

    res = None
    if len(frames):
        res = pd.concat(frames)

    users = list(users)
    dfu = pd.DataFrame(users)
    dfr = pd.DataFrame(runtypeids)

    if save:
        res.to_csv("allruns.csv", index=False)
        dfu.to_csv("users.csv", index=False)
        dfr.to_csv("runtypes.csv", index=False)

    if debug and res is not None:
        print(res.head())

    return res, dfu


dfg = pd.read_csv("game.csv")
get_all_runs(dfg, save=True)


def get_placement(df_games: pd.DataFrame, save=False):
    frames = []
    num = 0
    for i, game in enumerate(list(set(df_games.gid.values))):
        url = f"https://www.speedrun.com/api/v1/games/{game}/categories"
        response = requests.get(url)
        parsed = json.loads(response.text)
        if "data" in parsed:
            parsed = parsed["data"]
        else:
            continue

        if len(parsed) == 0:
            continue

        cframes = []
        for p in parsed:
            dfc = pd.json_normalize(p)
            dfc = dfc[["id"]]
            cframes.append(dfc)

        dfc_concat = pd.concat(cframes)

        for category in set(dfc_concat.id.values):
            url = f"https://www.speedrun.com/api/v1/leaderboards/{game}/category/{category}?top={100}"

            response = requests.get(url)
            parsed = json.loads(response.text)

            if "data" in parsed:
                parsed = parsed["data"]
            else:
                continue

            if "runs" in parsed:
                parsed = parsed["runs"]
            else:
                continue

            for run in parsed:
                dfg = pd.json_normalize(run)

                dfg = dfg[
                    [
                        "place",
                        "run.id",
                    ]
                ]

                dfg = dfg.rename(
                    columns={
                        "run.id": "RUNID",
                    }
                )

                dfg = dfg.drop(dfg[dfg.place <= 0].index)

                if not dfg.empty:
                    frames.append(dfg)
                    num += 1
                    print(num)

    res = pd.concat(frames)
    if save:
        res.to_csv("places.csv", index=False)
    print(res)
    return res
