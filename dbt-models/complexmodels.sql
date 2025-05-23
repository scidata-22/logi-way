//customer_segment_performance_with_delivery_analysis
-- customer_segment_performance_with_delivery_analysis.sql
WITH delivery_analysis AS (
  SELECT 
    f.CUSTOMER_ID,
    f.GLOBAL_FILE_ID,
    f.ORDER_DATE,
    f.DELIVERY_DATE,
    f.REQUESTED_DELIVERY_DATE,
    DATEDIFF(DAY,f.DELIVERY_DATE, f.REQUESTED_DELIVERY_DATE) AS DELIVERY_DELAY,
    f.REVENUE_USD,
    c.VERTICAL
  FROM SCREENING_BI.FREIGHT.FILES f
  JOIN SCREENING_BI.FREIGHT.CUSTOMERS c
    ON f.CUSTOMER_ID = c.CUSTOMER_ID
  WHERE f.DELIVERY_DATE IS NOT NULL AND f.REQUESTED_DELIVERY_DATE IS NOT NULL
),

performance_summary AS (
  SELECT
    CUSTOMER_ID,
    VERTICAL,
    COUNT(DISTINCT GLOBAL_FILE_ID) AS NUM_SHIPMENTS,
    SUM(REVENUE_USD) AS TOTAL_REVENUE_USD,
    AVG(DELIVERY_DELAY) AS AVG_DELIVERY_DELAY,
    COUNT(CASE WHEN DELIVERY_DELAY > 0 THEN 1 END) AS NUM_DELAYS,
    COUNT(CASE WHEN DELIVERY_DELAY < 0 THEN 1 END) AS NUM_EARLY_DELIVERIES
  FROM delivery_analysis
  GROUP BY CUSTOMER_ID, VERTICAL
)

SELECT * FROM performance_summary;


//carrier_performance_analysis_with_container_utilization
--carrier_performance_analysis_with_container_utilization.sql
WITH carrier_performance AS (
  SELECT
    f.CARRIERNAME,
    COUNT(DISTINCT f.GLOBAL_FILE_ID) AS NUM_SHIPMENTS,
    SUM(f.REVENUE_USD) AS TOTAL_REVENUE_USD
  FROM SCREENING_BI.FREIGHT.FILES f
  GROUP BY f.CARRIERNAME
),

container_utilization AS (
  SELECT
    c.GLOBAL_FILE_ID,  -- File ID from the CONTAINERS table
    SUM(c.TEU) AS TOTAL_TEU,  -- Sum of TEU from the CONTAINERS table
    COUNT(DISTINCT c.CONTAINER_ID) AS TOTAL_CONTAINERS  -- Count of distinct containers per file
  FROM SCREENING_BI.FREIGHT.CONTAINERS c
  GROUP BY c.GLOBAL_FILE_ID
)

SELECT
  cp.CARRIERNAME,
  cp.NUM_SHIPMENTS,
  cp.TOTAL_REVENUE_USD,
  cu.TOTAL_TEU,
  cu.TOTAL_CONTAINERS,
  (cp.TOTAL_REVENUE_USD / NULLIF(cp.NUM_SHIPMENTS, 0)) AS REVENUE_PER_SHIPMENT,
  (cu.TOTAL_TEU / NULLIF(cp.NUM_SHIPMENTS, 0)) AS TEU_PER_SHIPMENT,
  (cp.TOTAL_REVENUE_USD / NULLIF(cu.TOTAL_TEU, 0)) AS REVENUE_PER_TEU
FROM carrier_performance cp
LEFT JOIN container_utilization cu
  ON cp.CARRIERNAME = cu.GLOBAL_FILE_ID  -- Join using CARRIERNAME and GLOBAL_FILE_ID
ORDER BY cp.TOTAL_REVENUE_USD DESC;


