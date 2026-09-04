--
--  model: tsspica_analytics_daily_categories
--  description: This model is a landing table for tsspica_analytics_daily_categories data. It selects all columns from the tsspica_analytics_daily_categories source table and prepares it for further transformations.
--  

select 'TSSPICA' as LND_SRC_SYSTEM,
        SYSDATETIME() AS LND_LOAD_TS,
        {{ var('run_id') }} AS LND_RUN_ID,
        t1.*
    from [BTCSQL01\BTC].[TSSPICA].[dbo].[ANALYTICS_DAILY_CATEGORIES] t1