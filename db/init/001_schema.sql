-- wrc-telemetry-pipeline schema
-- Runs once, the first time TimescaleDB starts with an empty data folder.
-- Units are in the column names. All times are timestamptz (stored as UTC).

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ---------------------------------------------------------------------------
-- Reference data: few rows, rarely change
-- ---------------------------------------------------------------------------

CREATE TABLE rallies (
    id      serial PRIMARY KEY,
    name    text    NOT NULL,
    year    integer NOT NULL,
    country text,
    UNIQUE (name, year)              -- same rally, different year = different row
);

CREATE TABLE stages (
    id        serial PRIMARY KEY,
    rally_id  integer NOT NULL REFERENCES rallies (id),
    code      text    NOT NULL,      -- 'SS3'
    name      text,                  -- 'Loutraki'
    length_m  integer,
    UNIQUE (rally_id, code)
);

-- Who drives which car, per rally. Its own table because the pairing
-- changes from rally to rally.
CREATE TABLE entries (
    rally_id   integer NOT NULL REFERENCES rallies (id),
    car        text    NOT NULL,     -- 'car-1'
    driver     text    NOT NULL,
    co_driver  text,
    profile    text,                 -- simulator driving style: 'attacking', 'smooth', ...
    PRIMARY KEY (rally_id, car)
);

-- ---------------------------------------------------------------------------
-- Measurements: 50 Hz per car, millions of rows
-- ---------------------------------------------------------------------------

CREATE TABLE samples (
    ts               timestamptz      NOT NULL,  -- when the car measured it (car clock)
    car              text             NOT NULL,
    stage_id         integer          NOT NULL REFERENCES stages (id),
    source           text             NOT NULL CHECK (source IN ('live', 'logger')),
    seq              bigint           NOT NULL,  -- +1 per sample, per car and stage

    distance_m       real,            -- from the stage start; used to compare drivers
    speed_kmh        real,
    rpm              smallint,
    gear             smallint,        -- 0 = neutral, -1 = reverse
    throttle_pct     real,
    brake_pct        real,
    brake_temp_fl_c  real,
    brake_temp_fr_c  real,
    brake_temp_rl_c  real,
    brake_temp_rr_c  real,
    coolant_temp_c   real,
    boost_bar        real,
    g_lat            real,            -- in g
    g_long           real,            -- in g
    lat              double precision,
    lon              double precision,

    received_at      timestamptz      NOT NULL DEFAULT now(),  -- when it reached the DB; latency = received_at - ts

    -- What makes a sample unique. A duplicate (QoS 1 resend) has the same key,
    -- so INSERT ... ON CONFLICT DO NOTHING drops it. TimescaleDB requires the
    -- time column in every unique key, hence ts at the end.
    PRIMARY KEY (car, stage_id, source, seq, ts)
);

-- Split samples into chunks of one day. Old chunks can be compressed later.
SELECT create_hypertable('samples', by_range('ts', INTERVAL '1 day'));

-- ---------------------------------------------------------------------------
-- Events: a few rows per stage
-- ---------------------------------------------------------------------------

-- Missing seq ranges the ingester noticed on the live path.
-- A gap can close later, when the backlog arrives after a dead zone.
CREATE TABLE gaps (
    car          text        NOT NULL,
    stage_id     integer     NOT NULL REFERENCES stages (id),
    from_seq     bigint      NOT NULL,
    to_seq       bigint      NOT NULL,
    detected_at  timestamptz NOT NULL DEFAULT now(),
    filled_at    timestamptz,                     -- NULL = still missing
    PRIMARY KEY (car, stage_id, from_seq),
    CHECK (to_seq >= from_seq)
);

-- Online / offline changes, from the retained status topic and the last will.
CREATE TABLE car_status (
    ts      timestamptz NOT NULL,
    car     text        NOT NULL,
    status  text        NOT NULL CHECK (status IN ('online', 'offline')),
    PRIMARY KEY (car, ts)
);
