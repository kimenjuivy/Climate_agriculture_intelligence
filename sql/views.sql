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