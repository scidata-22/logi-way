-- models/revenue_by_carrier.sql

SELECT
    CARRIERNAME,
    SUM(REVENUE_USD) AS total_revenue,
    SUM(NET_REVENUE_USD) AS total_net_revenue
FROM SCREENING_BI.FREIGHT.FILES  -- Directly reference the full table name in Snowflake
GROUP BY CARRIERNAME
ORDER BY total_revenue DESC;
