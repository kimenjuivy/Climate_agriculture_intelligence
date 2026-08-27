-- ============================================
-- Climate & Agricultural Vulnerability Intelligence — schema
-- Note: CREATE DATABASE climate_agri_intelligence; was already run once,
-- connected to the default 'postgres' database (not repeated here).
-- ============================================

-- Dimension tables
CREATE TABLE countries (
    iso3 CHAR(3) PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL,
    continent VARCHAR(50),
    lon NUMERIC(9,6),
    lat NUMERIC(9,6)
);

CREATE TABLE calendar (
    year INT PRIMARY KEY,
    decade INT NOT NULL,
    period_label VARCHAR(10) NOT NULL,
    is_forecast BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE climate (
    iso3 CHAR(3) PRIMARY KEY REFERENCES countries(iso3),
    baseline_avg_temp_c NUMERIC(6,3),
    baseline_avg_precip_mm NUMERIC(10,3),
    baseline_start INT,
    baseline_end INT
);

-- Fact tables
CREATE TABLE weather (
    iso3 CHAR(3) REFERENCES countries(iso3),
    year INT REFERENCES calendar(year),
    avg_temp_c NUMERIC(6,3),
    total_precip_mm NUMERIC(10,3),
    PRIMARY KEY (iso3, year)
);

CREATE TABLE population (
    iso3 CHAR(3) REFERENCES countries(iso3),
    year INT REFERENCES calendar(year),
    population BIGINT,
    PRIMARY KEY (iso3, year)
);

CREATE TABLE crop_yields (
    iso3 CHAR(3) REFERENCES countries(iso3),
    year INT REFERENCES calendar(year),
    crop VARCHAR(30),
    yield_kg_ha NUMERIC(10,2),
    PRIMARY KEY (iso3, year, crop)
);