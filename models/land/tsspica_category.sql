--
--  model: tsspica_category
--  description: This model is a landing table for tsspica_category data. It selects all columns from the tsspica_category source table and prepares it for further transformations.    
--

select 'TSSPICA' as LND_SRC_SYSTEM,
        SYSDATETIME() AS LND_LOAD_TS,
        {{ var('run_id') }} AS LND_RUN_ID,
        t1.*
    from [BTCSQL01\BTC].[TSSPICA].[dbo].[CATEGORY] t1