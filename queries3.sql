SET
    SEARCH_PATH TO Speedrun;

DROP VIEW IF EXISTS GameCategoriesWithEmulators CASCADE;

DROP VIEW IF EXISTS RunsWithPossibleEmulation CASCADE;

DROP VIEW IF EXISTS EmulatedRuns CASCADE;

DROP VIEW IF EXISTS NonEmulatedRuns CASCADE;

DROP VIEW IF EXISTS EmulatedVsNonEmulated CASCADE;

DROP VIEW IF EXISTS RunsWithPossibleEmulation CASCADE;

DROP VIEW IF EXISTS AvgTimePerRegion CASCADE;

DROP VIEW IF EXISTS AvgTimePerGamePerRegion CASCADE;

DROP VIEW IF EXISTS SneakyMods CASCADE;

DROP VIEW IF EXISTS Leaderboard CASCADE;

DROP VIEW IF EXISTS SneakyModsRecords CASCADE;

-- Average run time for a game category (including only games that can have emulators)
-- with and without emulator
CREATE VIEW GameCategoriesWithEmulators AS
SELECT
    DISTINCT gid,
    runtypeid,
    regionname
FROM
    Run
WHERE
    isEmulated = TRUE;

CREATE VIEW RunsWithPossibleEmulation AS
SELECT
    r.gid,
    r.runid,
    r.runtypeid,
    r.duration,
    r.submissiondate,
    r.isemulated,
    r.eid,
    r.regionname,
    r.pid
FROM
    GameCategoriesWithEmulators g
    JOIN Run r ON g.gid = r.gid;

CREATE VIEW EmulatedRuns AS
SELECT
    gid,
    runtypeid,
    regionname,
    avg(duration) AS avgduration
FROM
    RunsWithPossibleEmulation
WHERE
    isemulated = TRUE
GROUP BY
    gid,
    runtypeid,
    regionname
ORDER BY
    gid;

CREATE VIEW NonEmulatedRuns AS
SELECT
    gid,
    runtypeid,
    regionname,
    avg(duration) AS avgduration
FROM
    RunsWithPossibleEmulation
WHERE
    isemulated = FALSE
GROUP BY
    gid,
    runtypeid,
    regionname
ORDER BY
    gid;

CREATE VIEW EmulatedVsNonEmulated AS
SELECT
    er.gid,
    er.runtypeid,
    er.regionname,
    er.avgduration AS emulatedAvgDuration,
    ner.avgduration AS nonEmulatedAvgDuration,
    er.avgduration / ner.avgduration AS emulatedOverNon
FROM
    EmulatedRuns er
    JOIN NonEmulatedRuns ner ON (
        er.gid = ner.gid
        AND er.runtypeid = ner.runtypeid
        AND er.regionname = ner.regionname
    );

SELECT
    AVG(emulatedOverNon)
FROM
    EmulatedVsNonEmulated;

--------------------------------------------------------------------------------
-- Which region is the best?
CREATE VIEW AvgTimePerRegion AS
SELECT
    regionname,
    AVG(duration) AS avgTime,
    -- NOTE: Limitation: we can't look for games which have all versions because that occurs for only few games.
    COUNT(*)
FROM
    Run
GROUP BY
    regionname
ORDER BY
    avgTime;

-- Let's try gamewise.
CREATE VIEW AvgTimePerGamePerRegion AS
SELECT
    gid,
    regionname,
    avg(duration) AS avgTime
FROM
    Run
GROUP BY
    gid,
    regionname
ORDER BY
    gid,
    avgtime,
    regionname;

--------------------------------------------------------------------------------
-- Are some examiners biased?
-- The number of times an examiner examined themselves
CREATE VIEW SneakyMods AS
SELECT
    playerName,
    s.selfExaminedCount
FROM
    (
        SELECT
            PID,
            count(*) AS selfExaminedCount
        FROM
            Run
        WHERE
            PID = EID
        GROUP BY
            PID
    ) s
    NATURAL JOIN Player
ORDER BY
    s.selfExaminedCount DESC;

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
    t.rnk,
    t.eid
FROM
    (
        SELECT
            runid,
            pid,
            gid,
            regionName,
            runTypeId,
            duration,
            eid,
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

-- Find examiners who won a world record from a run they examined.
CREATE VIEW SneakyModsRecords AS
SELECT
    playerName,
    s.selfExaminedRecords
FROM
    (
        SELECT
            PID,
            count(*) AS selfExaminedRecords
        FROM
            Leaderboard
        WHERE
            PID = EID
            AND rnk = 1
        GROUP BY
            PID
    ) s
    NATURAL JOIN Player
ORDER BY
    s.selfExaminedRecords DESC;

-- The proportion of the record winning runs to all self-examined runs.
CREATE VIEW SneakyModsRatio AS
SELECT
    sum(selfExaminedRecords) / sum(selfExaminedCount) AS selfExaminedRecordRatio
FROM
    SneakyMods
    NATURAL JOIN SneakyModsRecords;

-- Number of records won when the examiner was not the player.
CREATE VIEW NonSneakyRecords AS
SELECT
    count(*) AS nonSelfExaminedRecords
FROM
    Leaderboard
WHERE
    PID != EID
    AND rnk = 1;

-- Number of runs not examined by the player.
CREATE VIEW NonSneakyRuns AS
SELECT
    count(*) AS nonSelfExaminedRuns
FROM
    Leaderboard
WHERE
    PID != EID;

-- The proportion of record winning runs to all non-self-exmined runs.
CREATE VIEW NonSneakyModsRatio AS
SELECT
    (
        SELECT
            *
        FROM
            NonSneakyRecords
    ) :: FLOAT / (
        SELECT
            *
        FROM
            NonSneakyRuns
    ) AS NonSelfExaminedRecordRatio;

