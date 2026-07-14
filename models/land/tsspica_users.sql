select t1.*,
        'TSSPICA' as SRC_SYSTEM,
        GETDATE() as LOAD_TS
    from [BTCSQL01\BTC].[TSSPICA].[dbo].[USERS] t1