USE FiscalMonitor;
GO

CREATE TABLE dbo.dq_check_result (
    check_id       INT IDENTITY(1,1) PRIMARY KEY,
    run_id         INT           NOT NULL REFERENCES dbo.etl_run_log(run_id),
    source_file    VARCHAR(200)  NOT NULL,
    fiscal_year    INT           NULL,
    check_name     VARCHAR(100)  NOT NULL,
    max_difference DECIMAL(18,2) NOT NULL,
    tolerance      DECIMAL(18,2) NOT NULL,
    passed         BIT           NOT NULL,
    checked_at     DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
SELECT COUNT(*) AS n FROM dbo.dq_check_result;
