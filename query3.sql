SET
    SEARCH_PATH TO Speedrun;

DROP VIEW IF EXISTS GameCategoriesWithEmulators CASCADE;

DROP VIEW IF EXISTS RunsWithPossibleEmulation CASCADE;

-- average run time for game category (for a game that can have emulators) with and without emulator
-- other thing: look at top 10, prob of having emu
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
SELECT
    regionname,
    AVG(duration) AS avgTime -- but this could mean there are just lots of fast games for specific regions
    -- also maybe specific regions play certain run types usually
    -- limitation: we can't look for games which have all versions because it doesn't show up in our dataset
FROM
    Run
GROUP BY
    regionname
ORDER BY
    avgTime;

--- Let's try gamewise
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

