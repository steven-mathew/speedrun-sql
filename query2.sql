SET
    SEARCH_PATH TO Speedrun;

DROP VIEW IF EXISTS YearMonthRun CASCADE;

DROP VIEW IF EXISTS AvgMonthlyRunTimePerGameCatPerYear CASCADE;

DROP VIEW IF EXISTS AllYears CASCADE;

DROP VIEW IF EXISTS AllItemsAllYears CASCADE;

DROP VIEW IF EXISTS AllAvgMonthlyRunTimes CASCADE;

DROP VIEW IF EXISTS GameIds CASCADE;

CREATE VIEW YearMonthRun AS
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
    EXTRACT(
        MONTH
        FROM
            submissionDate
    ) AS mo,
    submissionDate,
    isEmulated,
    EID,
    regionName,
    PID
FROM
    Run;

CREATE VIEW AvgMonthlyRunTimePerGameCatPerYear AS
SELECT
    DISTINCT GID,
    --    regionName,
    runTypeId,
    yr,
    CAST(SUM(duration) AS FLOAT) / 12 AS avgMonthlyRunTime
FROM
    YearMonthRun
GROUP BY
    GID,
    --    regionName,
    runTypeId,
    yr
ORDER BY
    GID,
    --    regionName,
    runTypeId,
    yr;

SELECT
    *
FROM
    AvgMonthlyRunTimePerGameCatPerYear;

CREATE VIEW AllYears AS
SELECT
    generate_series AS yr
FROM
    generate_series(
        (
            SELECT
                min(yr) :: INT
            FROM
                YearMonthRun
        ),
        (
            SELECT
                max(yr) :: INT
            FROM
                YearMonthRun
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

CREATE VIEW AllAvgMonthlyRunTimes AS
SELECT
    DISTINCT aiay.gid,
    aiay.runTypeId,
    aiay.yr,
    COALESCE(avgMonthlyRunTime, 0.0) AS avgMonthlyRunTime
FROM
    AllItemsAllYears aiay
    LEFT JOIN AvgMonthlyRunTimePerGameCatPerYear iams ON (
        iams.gid = aiay.gid
        AND iams.runTypeId = aiay.runTypeId
        AND iams.yr = aiay.yr
    )
ORDER BY
    aiay.yr;

-- recall that the primary key is (gid, regionName)
CREATE VIEW GameIds AS
SELECT
    DISTINCT gid,
    gameName
FROM
    Game;

-- the change in yearly average between average monthly run times
-- of a game category
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
            a.avgMonthlyRunTime AS Year1Average,
            b.yr AS Year2,
            b.avgMonthlyRunTime AS Year2Average,
            (
                CASE
                    WHEN a.avgMonthlyRunTime = 0
                    AND b.avgMonthlyRunTime != 0 THEN 'Infinity' :: FLOAT
                    WHEN a.avgMonthlyRunTime = b.avgMonthlyRunTime THEN 0.0 :: FLOAT
                    ELSE CAST(
                        (
                            (b.avgMonthlyRunTime - a.avgMonthlyRunTime) / a.avgMonthlyRunTime * 100
                        ) AS FLOAT
                    )
                END
            ) AS yearOverYearChange
        FROM
            AllAvgMonthlyRunTimes a
            JOIN AllAvgMonthlyRunTimes b ON (
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

SELECT
    *
FROM
    GameAndCategoryYearOverYearChange
WHERE
    year2average != 0
    AND NOT (
        year1average = 0
        AND year2average = 0
        AND yearoveryearchange = 0
    )
ORDER BY
    yearOverYearChange;

-- Ignore where the game wasn't played in the first year
CREATE VIEW FilteredYOYChange AS
SELECT
    *
FROM
    GameAndCategoryYearOverYearChange
WHERE
    year1average != 0
    AND year2average != 0
    AND NOT (
        year1average = 0
        AND year2average = 0
        AND yearoveryearchange = 0
    )
ORDER BY
    yearOverYearChange;

-- you need to put this side by side with popularity year over year
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

SELECT
    year1,
    year2,
    COUNT(*) AS numYearIntervals,
    COUNT(*) / (
        SELECT
            SUM(cnt)
        FROM
            AverageChangePerYearInterval
    ) AS weightOrNumYearIntervalsOutOfTotal,
    AVG(yearoveryearchange) AS avgYearOverYearChange,
    AVG(yearoveryearchange) * (
        COUNT(*) / (
            SELECT
                SUM(cnt)
            FROM
                AverageChangePerYearInterval
        )
    ) AS weightedAvgYearOverYearChange
FROM
    FilteredYOYChange
GROUP BY
    year1,
    year2
ORDER BY
    year1;

-----------

