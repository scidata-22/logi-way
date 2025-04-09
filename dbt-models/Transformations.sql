
WITH container_cleaned AS (
  SELECT 
    GLOBAL_FILE_ID,
    LOAD_TERMS,
    CONTAINER_ID,
    VESSEL,
    VOYAGE,
    QUANTITY,
    TEU
  FROM SCREENING_BI.FREIGHT.CONTAINERS
  WHERE 
    -- Condition: Container ID should not be null
    CONTAINER_ID IS NOT NULL
)

SELECT * 
FROM container_cleaned;








