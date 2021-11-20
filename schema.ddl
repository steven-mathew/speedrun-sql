DROP SCHEMA IF EXISTS Speedrun CASCADE;
CREATE SCHEMA Speedrun;
SET SEARCH_PATH TO Speedrun;



CREATE DOMAIN RegionDomain as VARCHAR(255)
    CONSTRAINT validRegionName
        CHECK (value in ('EUR / PAL', 'BRA / PAL', 'CHN / PAL', 'JPN / NTSC', 
        'KOR / NTSC', 'USA / NTSC'));



-- A country called countryName with the ISO Alpha-2 code CID.
CREATE TABLE Country (
    countryName VARCHAR(255) NOT NULL,
    CID CHAR(2) NOT NULL,
    PRIMARY KEY (CID)
);

-- A speedrun.com player called playerName with a PID id and registered in the 
-- country CID.
CREATE TABLE Player (
    PID VARCHAR(255) NOT NULL,
    playerName VARCHAR(255) NOT NULL,
    CID CHAR(2) NOT NULL,
    PRIMARY KEY (PID),
    FOREIGN KEY (CID) REFERENCES Country(CID)
);

-- A video game called gameName with id GID has a special version for the region
-- called regionName.
CREATE TABLE Game (
    GID VARCHAR(255) NOT NULL,
    gameName VARCHAR(255) NOT NULL,
    regionName RegionDomain NOT NULL,
    PRIMARY KEY (GID, regionName)
);

-- A run type is a ruleset imposed on a run. A tuple in this table is a run type
-- called runTypeName with id RUNTYPEID.
CREATE TABLE RunType (
    RUNTYPEID VARCHAR(255) NOT NULL,
    runTypeName VARCHAR(255) NOT NULL,
    PRIMARY KEY (RUNTYPEID)
);

-- A speedrun RUNID of type RUNTYPEID for the game GID and version regionName 
-- was completed in duration (seconds.milliseconds) and submitted on 
-- submissionDate. isEmulated specifies if the run was done on an emulator. 
-- PID is the player who completed the run and EID examined the run.
CREATE TABLE Run (
    RUNID VARCHAR(255) NOT NULL,
    RUNTYPEID VARCHAR(255) NOT NULL,
    GID VARCHAR(255) NOT NULL,
    duration FLOAT NOT NULL,
    submissionDate DATE NOT NULL,
    isEmulated BOOLEAN NOT NULL,
    EID VARCHAR(255) NOT NULL,
    regionName RegionDomain NOT NULL,
    PID VARCHAR(255) NOT NULL,
    PRIMARY KEY (RUNID),
    FOREIGN KEY (RUNTYPEID) REFERENCES RunType(RUNTYPEID),
    FOREIGN KEY (EID) REFERENCES Player(PID),
    FOREIGN KEY (PID) REFERENCES Player(PID),
    FOREIGN KEY (GID, regionName) REFERENCES Game(GID, regionName),
    CONSTRAINT positiveDuration
        CHECK (duration >= 0)
);