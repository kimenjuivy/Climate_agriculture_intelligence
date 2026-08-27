
-- Sanity check first: this should return exactly 13,745 — matching crop_yields' own
-- row count exactly, since weather covers every country/year crop_yields could reference.
-- A number LARGER than that would mean a join is fanning out rows (a duplicate-key bug);
-- smaller would mean some crop_yields rows have no matching weather data.
SELECT COUNT(*) 
FROM crop_yields cy
JOIN countries c ON cy.iso3 = c.iso3
JOIN weather w ON cy.iso3 = w.iso3 AND cy.year = w.year;



SELECT
    c.country_name,
    c.continent,
    cy.year,
    cy.crop,
    cy.yield_kg_ha,
    w.avg_temp_c,
    w.total_precip_mm
FROM crop_yields cy
JOIN countries c ON cy.iso3 = c.iso3
JOIN weather w ON cy.iso3 = w.iso3 AND cy.year = w.year
ORDER BY c.country_name, cy.crop, cy.year
LIMIT 20;


SELECT
    cy.year,
    cy.yield_kg_ha,
    LAG(cy.yield_kg_ha) OVER (PARTITION BY cy.iso3, cy.crop ORDER BY cy.year) AS prev_year_yield,
    ROUND(
        100.0 * (cy.yield_kg_ha - LAG(cy.yield_kg_ha) OVER (PARTITION BY cy.iso3, cy.crop ORDER BY cy.year))
        / NULLIF(LAG(cy.yield_kg_ha) OVER (PARTITION BY cy.iso3, cy.crop ORDER BY cy.year), 0)
    , 2) AS yield_growth_pct
FROM crop_yields cy
WHERE cy.iso3 = 'AFG' AND cy.crop = 'Maize (corn)'
ORDER BY cy.year;


WITH yield_with_growth AS (
    SELECT
        cy.iso3,
        c.country_name,
        c.continent,
        cy.crop,
        cy.year,
        cy.yield_kg_ha,
        LAG(cy.yield_kg_ha) OVER (PARTITION BY cy.iso3, cy.crop ORDER BY cy.year) AS prev_year_yield
    FROM crop_yields cy
    JOIN countries c ON cy.iso3 = c.iso3
)
SELECT
    country_name,
    continent,
    crop,
    year,
    yield_kg_ha,
    prev_year_yield,
    ROUND(100.0 * (yield_kg_ha - prev_year_yield) / NULLIF(prev_year_yield, 0), 2) AS yield_growth_pct
FROM yield_with_growth
ORDER BY country_name, crop, year
LIMIT 30;



WITH yield_with_growth AS (
    SELECT
        cy.iso3,
        c.country_name,
        c.continent,
        cy.crop,
        cy.year,
        cy.yield_kg_ha,
        LAG(cy.yield_kg_ha) OVER (PARTITION BY cy.iso3, cy.crop ORDER BY cy.year) AS prev_year_yield
    FROM crop_yields cy
    JOIN countries c ON cy.iso3 = c.iso3
)
SELECT
    country_name,
    continent,
    crop,
    year,
    yield_kg_ha,
    prev_year_yield,
    ROUND(100.0 * (yield_kg_ha - prev_year_yield) / NULLIF(prev_year_yield, 0), 2) AS yield_growth_pct
FROM yield_with_growth
ORDER BY country_name, crop, year
LIMIT 30;