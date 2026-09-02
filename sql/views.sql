CREATE VIEW vw_country_yearly_summary AS
WITH yield_with_growth AS (
    SELECT
        cy.iso3,
        cy.crop,
        cy.year,
        cy.yield_kg_ha,
        LAG(cy.yield_kg_ha) OVER (PARTITION BY cy.iso3, cy.crop ORDER BY cy.year) AS prev_year_yield
    FROM crop_yields cy
)
SELECT
    c.iso3,
    c.country_name,
    c.continent,
    yg.crop,
    yg.year,
    yg.yield_kg_ha,
    yg.prev_year_yield,
    ROUND(100.0 * (yg.yield_kg_ha - yg.prev_year_yield) / NULLIF(yg.prev_year_yield, 0), 2) AS yield_growth_pct,
    w.avg_temp_c,
    w.total_precip_mm,
    cl.baseline_avg_temp_c,
    cl.baseline_avg_precip_mm,
    ROUND(w.avg_temp_c - cl.baseline_avg_temp_c, 2) AS temp_anomaly_c,
    ROUND(w.total_precip_mm - cl.baseline_avg_precip_mm, 2) AS precip_anomaly_mm,
    p.population
FROM yield_with_growth yg
JOIN countries c ON yg.iso3 = c.iso3
JOIN weather w ON yg.iso3 = w.iso3 AND yg.year = w.year
LEFT JOIN climate cl ON yg.iso3 = cl.iso3
LEFT JOIN population p ON yg.iso3 = p.iso3 AND yg.year = p.year;


SELECT COUNT(*) FROM vw_country_yearly_summary;

SELECT * FROM vw_country_yearly_summary
ORDER BY country_name, crop, year
LIMIT 20;

CREATE VIEW vw_regional_risk AS
WITH crop_trends AS (
    SELECT
        cy.iso3,
        cy.crop,
        regr_slope(cy.yield_kg_ha, cy.year) AS slope_kg_ha_per_year,
        regr_r2(cy.yield_kg_ha, cy.year) AS trend_r2,
        regr_count(cy.yield_kg_ha, cy.year) AS n_years,
        AVG(cy.yield_kg_ha) AS mean_yield
    FROM crop_yields cy
    GROUP BY cy.iso3, cy.crop
),
reliable_trends AS (
    SELECT
        iso3,
        crop,
        trend_r2,
        n_years,
        100.0 * slope_kg_ha_per_year / NULLIF(mean_yield, 0) AS slope_pct_per_year
    FROM crop_trends
    WHERE n_years >= 20 AND trend_r2 >= 0.3
),
country_climate_volatility AS (
    SELECT
        w.iso3,
        STDDEV(w.avg_temp_c - cl.baseline_avg_temp_c) AS temp_volatility,
        STDDEV(w.total_precip_mm - cl.baseline_avg_precip_mm) AS precip_volatility
    FROM weather w
    JOIN climate cl ON w.iso3 = cl.iso3
    GROUP BY w.iso3
),
combined AS (
    SELECT
        rt.iso3,
        rt.crop,
        GREATEST(-rt.slope_pct_per_year, 0) AS decline_severity,
        ccv.temp_volatility,
        ccv.precip_volatility
    FROM reliable_trends rt
    JOIN country_climate_volatility ccv ON rt.iso3 = ccv.iso3
),
normalized AS (
    SELECT
        *,
        (decline_severity - MIN(decline_severity) OVER ()) / NULLIF(MAX(decline_severity) OVER () - MIN(decline_severity) OVER (), 0) AS decline_severity_norm,
        (temp_volatility - MIN(temp_volatility) OVER ()) / NULLIF(MAX(temp_volatility) OVER () - MIN(temp_volatility) OVER (), 0) AS temp_volatility_norm,
        (precip_volatility - MIN(precip_volatility) OVER ()) / NULLIF(MAX(precip_volatility) OVER () - MIN(precip_volatility) OVER (), 0) AS precip_volatility_norm
    FROM combined
),
scored AS (
    SELECT
        *,
        decline_severity_norm * ((temp_volatility_norm + precip_volatility_norm) / 2) AS vulnerability_index
    FROM normalized
),
country_rollup AS (
    SELECT
        iso3, crop AS worst_crop, vulnerability_index AS max_vulnerability_index,
        ROW_NUMBER() OVER (PARTITION BY iso3 ORDER BY vulnerability_index DESC) AS rn
    FROM scored
),
country_avg AS (
    SELECT iso3, AVG(vulnerability_index) AS avg_vulnerability_index, COUNT(*) AS num_crops_at_risk
    FROM scored
    GROUP BY iso3
)
SELECT
    c.iso3, c.country_name, c.continent,
    cr.worst_crop, cr.max_vulnerability_index,
    ca.avg_vulnerability_index, ca.num_crops_at_risk
FROM country_rollup cr
JOIN country_avg ca ON cr.iso3 = ca.iso3
JOIN countries c ON cr.iso3 = c.iso3
WHERE cr.rn = 1
ORDER BY cr.max_vulnerability_index DESC;