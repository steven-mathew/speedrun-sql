SET
    SEARCH_PATH TO Speedrun;

DROP VIEW IF EXISTS Leaderboard CASCADE;

DROP VIEW IF EXISTS Top3Counts CASCADE;

DROP VIEW IF EXISTS WellRounders CASCADE;

DROP VIEW IF EXISTS TopCountriesRelativeCount CASCADE;

DROP VIEW IF EXISTS TopCountriesRelativeCountFiltered3 CASCADE;

DROP VIEW IF EXISTS TopCountriesRelativeCountFiltered20 CASCADE;

DROP VIEW IF EXISTS PeoplePerCountry CASCADE;

DROP VIEW IF EXISTS TopCountriesAbsoluteCount CASCADE;

DROP VIEW IF EXISTS Top5 CASCADE;

-- Define views for your intermediate steps here:
CREATE VIEW Leaderboard AS
SELECT
    DISTINCT t.runid,
    p.pid,
    p.playerName,
    g.gameName,
    g.gid,
    t.regionName,
    t.runTypeId,
    t.duration,
    t.rnk
FROM
    (
        SELECT
            runid,
            pid,
            gid,
            regionName,
            runTypeId,
            duration,
            RANK() OVER (
                PARTITION BY gid,
                regionName,
                runTypeId
                ORDER BY
                    duration
            ) AS rnk
        FROM
            Run
    ) t
    JOIN Player p ON t.pid = p.pid
    JOIN Game g ON t.gid = g.gid
ORDER BY
    gameName,
    regionName,
    runTypeId,
    rnk;

--------------------------------------------------------------------------------
-- Which speedrunners are most talented?
-- The number of top 3 placements a player has
CREATE VIEW Top3Counts AS
SELECT
    p.pid,
    playerName,
    cid,
    cnt
FROM
    (
        SELECT
            pid,
            COUNT(*) AS cnt
        FROM
            Leaderboard
        WHERE
            rnk <= 3
        GROUP BY
            pid
    ) z
    JOIN Player p ON z.pid = p.pid
ORDER BY
    cnt DESC;

-- Players that hold rank 1 in multiple games (> 1 games)
CREATE VIEW WellRounders AS
SELECT
    p.pid,
    p.playerName,
    cid,
    cnt
FROM
    (
        SELECT
            t.pid,
            COUNT(*) AS cnt
        FROM
            (
                SELECT
                    DISTINCT pid,
                    gameName
                FROM
                    Leaderboard
                WHERE
                    rnk = 1
            ) t
            JOIN Player p ON t.pid = p.pid
        GROUP BY
            t.pid
        ORDER BY
            cnt DESC
    ) z
    JOIN Player p ON z.pid = p.pid
WHERE
    cnt > 1
ORDER BY
    cnt DESC;

--------------------------------------------------------------------------------
-- Which countries excel in the leaderboards?
CREATE VIEW TopCountriesAbsoluteCount AS
SELECT
    cid,
    countryName,
    COALESCE(cnt, 0) AS cnt
FROM
    (
        SELECT
            cid,
            count(*) AS cnt
        FROM
            Top3Counts
        GROUP BY
            cid
    ) t
    RIGHT JOIN Country USING (CID)
ORDER BY
    cnt DESC;

-- Number of people per country
CREATE VIEW PeoplePerCountry AS
SELECT
    cid,
    count(*) AS cnt
FROM
    Player
GROUP BY
    cid
ORDER BY
    cnt DESC;

-- Now, relative to how many are in that country
CREATE VIEW TopCountriesRelativeCount AS
SELECT
    cid,
    countryName,
    COALESCE(CAST(tca.cnt AS FLOAT) / ppc.cnt, 0) AS ratio
FROM
    TopCountriesAbsoluteCount tca
    LEFT JOIN PeoplePerCountry ppc USING (cid)
ORDER BY
    ratio DESC;

-- But actually, there are lots of countries where there's few players and they did well
CREATE VIEW TopCountriesRelativeCountFiltered3 AS
SELECT
    cid,
    countryName,
    COALESCE(CAST(tca.cnt AS FLOAT) / ppc.cnt, 0) AS ratio
FROM
    TopCountriesAbsoluteCount tca
    LEFT JOIN PeoplePerCountry ppc USING (cid)
WHERE
    tca.cnt >= 3 -- if there were over 3 players who have placed top 3 in a country
ORDER BY
    ratio DESC;

CREATE VIEW TopCountriesRelativeCountFiltered20 AS
SELECT
    cid,
    countryName,
    COALESCE(CAST(tca.cnt AS FLOAT) / ppc.cnt, 0) AS ratio
FROM
    TopCountriesAbsoluteCount tca
    LEFT JOIN PeoplePerCountry ppc USING (cid)
WHERE
    tca.cnt >= 20 -- if there were over 20 players who have placed top 3 in a country
ORDER BY
    ratio DESC;

--------------------------------------------------------------------------------
-- Rivals
-- a player has at least one top 5 run for a particular game, runtype, game region
-- this means if a player has many runs for a (game, runtype, game region) grouping,
-- then they appear only once in the table
CREATE VIEW Top5 AS
SELECT
    DISTINCT pid,
    playername,
    gamename,
    gid,
    regionname,
    runtypeid
FROM
    Leaderboard
WHERE
    rnk <= 5
ORDER BY
    gid;

--------- just for example for us to see
SELECT
    *
FROM
    Top5 a
    JOIN Top5 b ON (
        a.pid < b.pid
        AND a.gid = b.gid
        AND a.runtypeid = b.runtypeid
        AND a.regionname = b.regionname
    );

------
-- the number of times that a pair of players placed in the top5 of the same category
CREATE VIEW RivalsAndMatches AS
SELECT
    player1,
    p2.playername AS player2,
    cnt AS num_times_matched_in_category
FROM
    (
        SELECT
            p1.playername AS player1,
            bpid,
            cnt
        FROM
            (
                SELECT
                    a.pid AS apid,
                    b.pid AS bpid,
                    COUNT(*) AS cnt
                FROM
                    Top5 a
                    JOIN Top5 b ON (
                        a.pid < b.pid
                        AND a.gid = b.gid -- define category to be gid, runtypeid, regionname triplet
                        AND a.runtypeid = b.runtypeid
                        AND a.regionname = b.regionname
                    )
                GROUP BY
                    a.pid,
                    b.pid
                HAVING
                    COUNT(*) > 1
                ORDER BY
                    cnt DESC
            ) t
            JOIN Player p1 ON (apid = p1.pid)
    ) z
    JOIN Player p2 ON (bpid = p2.pid);

-------- EXTRA
CREATE VIEW Top2 AS
SELECT
    DISTINCT pid,
    playername,
    gamename,
    gid,
    regionname,
    runtypeid
FROM
    Leaderboard
WHERE
    rnk <= 2
ORDER BY
    gid;

-- the number of times that a pair of players placed in the top5 of the same category
CREATE VIEW NemeesesAndMatches AS
SELECT
    player1,
    p2.playername AS player2,
    cnt AS num_times_matched_in_category
FROM
    (
        SELECT
            p1.playername AS player1,
            bpid,
            cnt
        FROM
            (
                SELECT
                    a.pid AS apid,
                    b.pid AS bpid,
                    COUNT(*) AS cnt
                FROM
                    Top2 a
                    JOIN Top2 b ON (
                        a.pid < b.pid
                        AND a.gid = b.gid -- define category to be gid, runtypeid, regionname triplet
                        AND a.runtypeid = b.runtypeid
                        AND a.regionname = b.regionname
                    )
                GROUP BY
                    a.pid,
                    b.pid
                HAVING
                    COUNT(*) > 1
                ORDER BY
                    cnt DESC
            ) t
            JOIN Player p1 ON (apid = p1.pid)
    ) z
    JOIN Player p2 ON (bpid = p2.pid);

