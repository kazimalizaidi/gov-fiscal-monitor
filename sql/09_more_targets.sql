USE FiscalMonitor;
GO

-- FBR taxes targets for FY2024 and FY2025 (PKR million, federal only).
-- Sources: Annual Budget Statement FY2024-25 and FY2025-26, Finance Division.
-- Safe to re-run: a row is inserted only if that year/indicator/type is missing.
INSERT INTO dbo.fiscal_target
    (fiscal_year, indicator, target_type, target_pkr_mn, scope, compare_to_line, source_doc, source_ref, notes)
SELECT v.fiscal_year, v.indicator, v.target_type, v.target_pkr_mn, v.scope,
       v.compare_to_line, v.source_doc, v.source_ref, v.notes
FROM (VALUES
    (2025, 'FBR_TAXES', 'BUDGET',  12970000, 'FEDERAL', 'TAX_FEDERAL', 'Annual Budget Statement FY2025-26', 'Revenue Receipts, FBR Taxes, Budget 2024-25',  CAST(NULL AS VARCHAR(300))),
    (2025, 'FBR_TAXES', 'REVISED', 11900000, 'FEDERAL', 'TAX_FEDERAL', 'Annual Budget Statement FY2025-26', 'Revenue Receipts, FBR Taxes, Revised 2024-25', NULL),
    (2024, 'FBR_TAXES', 'BUDGET',   9415000, 'FEDERAL', 'TAX_FEDERAL', 'Annual Budget Statement FY2024-25', 'Revenue Receipts, FBR Taxes, Budget 2023-24',  NULL),
    (2024, 'FBR_TAXES', 'REVISED',  9252000, 'FEDERAL', 'TAX_FEDERAL', 'Annual Budget Statement FY2024-25', 'Revenue Receipts, FBR Taxes, Revised 2023-24', NULL)
) AS v(fiscal_year, indicator, target_type, target_pkr_mn, scope, compare_to_line, source_doc, source_ref, notes)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.fiscal_target t
    WHERE t.fiscal_year = v.fiscal_year AND t.indicator = v.indicator AND t.target_type = v.target_type);
GO

UPDATE dbo.fiscal_target
SET notes = 'Federal tax in Table 1 matches the SBP Bulletin FBR Taxes series to rounding'
WHERE indicator = 'FBR_TAXES';
GO

SELECT fiscal_year, target_type, target_pkr_mn FROM dbo.fiscal_target ORDER BY fiscal_year, target_type;