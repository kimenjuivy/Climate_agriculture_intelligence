-- vw_vulnerability_by_crop
-- One row per (country, crop) with the full vulnerability-index breakdown.
-- Same logic as vw_regional_risk (which keeps only each country's worst crop),
-- so the scores reconcile exactly. Save a copy of this block in sql/views.sql.

CREATE OR REPLACE VIEW vw_vulnerability_by_crop AS
WITH crop_trends AS (
    SELECT cy.iso3, cy.crop,
        regr_slope(cy.yield_kg_ha, cy.year) AS slope_kg_ha_per_year,
        regr_r2(cy.yield_kg_ha, cy.year) AS trend_r2,
        regr_count(cy.yield_kg_ha, cy.year) AS n_years,
        AVG(cy.yield_kg_ha) AS mean_yield
    FROM crop_yields cy
    GROUP BY cy.iso3, cy.crop
),
reliable_trends AS (
    SELECT iso3, crop, trend_r2, n_years, mean_yield,
        100.0 * slope_kg_ha_per_year / NULLIF(mean_yield, 0) AS slope_pct_per_year
    FROM crop_trends
    WHERE n_years >= 20 AND trend_r2 >= 0.3
),
country_climate_volatility AS (
    SELECT w.iso3,
        STDDEV(w.avg_temp_c - cl.baseline_avg_temp_c) AS temp_volatility,
        STDDEV(w.total_precip_mm - cl.baseline_avg_precip_mm) AS precip_volatility
    FROM weather w JOIN climate cl ON w.iso3 = cl.iso3
    GROUP BY w.iso3
),
combined AS (
    SELECT rt.iso3, rt.crop, rt.slope_pct_per_year, rt.trend_r2, rt.n_years, rt.mean_yield,
        GREATEST(-rt.slope_pct_per_year, 0) AS decline_severity,
        ccv.temp_volatility, ccv.precip_volatility
    FROM reliable_trends rt
    JOIN country_climate_volatility ccv ON rt.iso3 = ccv.iso3
),
normalized AS (
    SELECT *,
        (decline_severity - MIN(decline_severity) OVER ()) / NULLIF(MAX(decline_severity) OVER () - MIN(decline_severity) OVER (), 0) AS decline_severity_norm,
        (temp_volatility - MIN(temp_volatility) OVER ()) / NULLIF(MAX(temp_volatility) OVER () - MIN(temp_volatility) OVER (), 0) AS temp_volatility_norm,
        (precip_volatility - MIN(precip_volatility) OVER ()) / NULLIF(MAX(precip_volatility) OVER () - MIN(precip_volatility) OVER (), 0) AS precip_volatility_norm
    FROM combined
),
scored AS (
    SELECT *, decline_severity_norm * ((temp_volatility_norm + precip_volatility_norm) / 2) AS vulnerability_index
    FROM normalized
)
SELECT c.iso3, c.country_name, c.continent, s.crop,
    s.slope_pct_per_year, s.trend_r2, s.n_years, s.mean_yield,
    s.decline_severity, s.temp_volatility, s.precip_volatility,
    s.decline_severity_norm, s.temp_volatility_norm, s.precip_volatility_norm,
    s.vulnerability_index
FROM scored s
JOIN countries c ON s.iso3 = c.iso3;


-- ============================================================
-- CHECK 1 (must return 0): best crop score per country must equal
-- the score already reported by vw_regional_risk.
-- ============================================================
SELECT COUNT(*) AS mismatches
FROM (
    SELECT iso3, MAX(vulnerability_index) AS best
    FROM vw_vulnerability_by_crop
    GROUP BY iso3
) a
JOIN vw_regional_risk r ON a.iso3 = r.iso3
WHERE ABS(a.best - r.max_vulnerability_index) > 1e-9;

-- ============================================================
-- CHECK 2 (both columns must be equal): same set of countries.
-- ============================================================
SELECT
    (SELECT COUNT(DISTINCT iso3) FROM vw_vulnerability_by_crop) AS countries_in_new_view,
    (SELECT COUNT(*) FROM vw_regional_risk)                     AS countries_in_old_view;