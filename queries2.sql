SET
    SEARCH_PATH TO Speedrun;

DROP VIEW IF EXISTS YearRun CASCADE;

DROP VIEW IF EXISTS AvgRunTimePerGameCatPerYear CASCADE;

DROP VIEW IF EXISTS AllYears CASCADE;

DROP VIEW IF EXISTS AllItemsAllYears CASCADE;

DROP VIEW IF EXISTS AllAvgRunTimes CASCADE;

DROP VIEW IF EXISTS GameIds CASCADE;

DROP VIEW IF EXISTS Leaderboard CASCADE;

DROP VIEW IF EXISTS RankOnes CASCADE;

DROP VIEW IF EXISTS NumAttemptsBeforeRankOne CASCADE;

DROP VIEW IF EXISTS AverageNumAttemptsBeforeRankOne CASCADE;

DROP VIEW IF EXISTS AvgRecordYear CASCADE;

-- All the runs with the year was submitted.
CREATE VIEW YearRun AS
SELECT
    RUNID,
    RUNTYPEID,
    GID,
    duration,
    EXTRACT(
        YEAR
        FROM
            submissionDate
    ) AS yr,
    submissionDate,
    isEmulated,
    EID,
    regionName,
    PID
FROM
    Run;

-- Yearly average run time per game, runtype pairing.
CREATE VIEW AvgRunTimePerGameCatPerYear AS
SELECT
    DISTINCT GID,
    runTypeId,
    yr,
    CAST(SUM(duration) AS FLOAT) / COUNT(*) AS avgRunTime
FROM
    YearRun
GROUP BY
    GID,
    runTypeId,
    yr
ORDER BY
    GID,
    runTypeId,
    yr;

-- Average yearly runtime with the number of game, runtype pairings used to
-- calculate average.
CREATE VIEW AvgRunTimesWithCount AS
SELECT
    yr,
    AVG(avgRunTime),
    COUNT(*)
FROM
    AvgRunTimePerGameCatPerYear
GROUP BY
    yr
ORDER BY
    yr;

-- All the years from the oldest to latest year.
CREATE VIEW AllYears AS
SELECT
    generate_series AS yr
FROM
    generate_series(
        (
            SELECT
                min(yr) :: INT
            FROM
                YearRun
        ),
        (
            SELECT
                max(yr) :: INT
            FROM
                YearRun
        )
    );

CREATE VIEW AllItemsAllYears AS
SELECT
    DISTINCT GID,
    runTypeId,
    ay.yr
FROM
    (
        SELECT
            GID,
            runTypeId
        FROM
            Run
    ) g,
    AllYears ay;

-- Average yearly run time for a game, runtype pairing.
CREATE VIEW AllAvgRunTimes AS
SELECT
    DISTINCT aiay.gid,
    aiay.runTypeId,
    aiay.yr,
    COALESCE(avgRunTime, 0.0) AS avgRunTime
FROM
    AllItemsAllYears aiay
    LEFT JOIN AvgRunTimePerGameCatPerYear iams ON (
        iams.gid = aiay.gid
        AND iams.runTypeId = aiay.runTypeId
        AND iams.yr = aiay.yr
    )
ORDER BY
    aiay.yr;

CREATE VIEW GameIds AS
SELECT
    DISTINCT gid,
    gameName
FROM
    Game;

-- The change in yearly average between average run times
-- of a game category.
CREATE VIEW GameAndCategoryYearOverYearChange AS
SELECT
    gameName,
    runTypeName,
    year1,
    year1Average,
    year2,
    year2Average,
    yearOverYearChange
FROM
    (
        SELECT
            DISTINCT a.gid,
            a.runTypeId,
            a.yr AS Year1,
            a.avgRunTime AS Year1Average,
            b.yr AS Year2,
            b.avgRunTime AS Year2Average,
            (
                CASE
                    WHEN a.avgRunTime = 0
                    AND b.avgRunTime != 0 THEN 'Infinity' :: FLOAT
                    WHEN a.avgRunTime = b.avgRunTime THEN 0.0 :: FLOAT
                    ELSE CAST(
                        ((b.avgRunTime - a.avgRunTime) / a.avgRunTime * 100) AS FLOAT
                    )
                END
            ) AS yearOverYearChange
        FROM
            AllAvgRunTimes a
            JOIN AllAvgRunTimes b ON (
                a.gid = b.gid
                AND a.runTypeId = b.runTypeId
                AND a.yr = b.yr - 1
            )
    ) z
    JOIN RunType rt ON z.runTypeId = rt.runTypeId
    JOIN GameIds g ON z.gid = g.gid
ORDER BY
    year1,
    gameName,
    yearOverYearChange;

-- The above query with a filter. See comments
CREATE VIEW FilteredYOYChange AS
SELECT
    *
FROM
    GameAndCategoryYearOverYearChange
WHERE
    year1average != 0 -- Ignore where the game wasn't played in the first year.
    AND year2average != 0
    AND NOT (
        year1average = 0
        AND year2average = 0
        AND yearoveryearchange = 0
    )
ORDER BY
    yearOverYearChange;

CREATE VIEW AverageChangePerYearInterval AS
SELECT
    year1,
    year2,
    COUNT(*) AS cnt,
    AVG(yearoveryearchange) AS avg
FROM
    FilteredYOYChange
GROUP BY
    year1,
    year2
ORDER BY
    year1;

-- Include the weighting for the population.
CREATE VIEW YearIntervalsAverageAndWeighted AS
SELECT
    year1,
    year2,
    COUNT(*) AS numYearIntervals,
    AVG(yearoveryearchange) AS avgYearOverYearChange
FROM
    FilteredYOYChange
GROUP BY
    year1,
    year2
ORDER BY
    year1;

--------------------------------------------------------------------------------
-- How many attempts on average does it take to get a world record?
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
    t.submissionDate,
    t.rnk,
    EXTRACT(
        YEAR
        FROM
            t.submissionDate
    ) AS yr
FROM
    (
        SELECT
            runid,
            pid,
            gid,
            regionName,
            runTypeId,
            duration,
            submissionDate,
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

-- Get all the number one people
CREATE VIEW RankOnes AS
SELECT
    *
FROM
    Leaderboard
WHERE
    rnk = 1;

CREATE VIEW NumAttemptsBeforeRankOne AS
SELECT
    l.pid,
    l.gameName,
    l.regionName,
    l.runTypeId,
    COUNT(*) AS cnt
FROM
    RankOnes r
    JOIN Leaderboard l ON (
        r.pid = l.pid
        AND r.gid = l.gid
        AND r.regionname = l.regionname
        AND r.runtypeid = l.runtypeid
        AND l.submissiondate < r.submissiondate
        AND r.runid != l.runid
    )
GROUP BY
    l.pid,
    l.gameName,
    l.regionname,
    l.runtypeid
ORDER BY
    l.pid;

-- This is lower than we expect because these are runs that speedrunners
-- are willing to submit, _NOT_ all the runs they've ever done.
-- Naturally, this is a limitation because it depends on the runner
-- if they want to submit the speed run or not.
CREATE VIEW AverageNumAttemptsBeforeRankOne AS
SELECT
    AVG(cnt) AS avgNumAttempsBeforeRankOneNum
FROM
    NumAttemptsBeforeRankOne;

--------------------------------------------------------------------------------
--  It is the average year of record-breaking runs.
CREATE VIEW AvgRecordYear AS
SELECT
    AVG(yr) AS avgYear
FROM
    Leaderboard
WHERE
    rnk = 1;

