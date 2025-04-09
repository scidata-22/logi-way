// Model for Revenue (Month-over-Month / Year-over-Year)
 --models/revenue_growth.sql-- models/monthly_yearly_revenue.sql

WITH revenue_data AS (
  SELECT
    -- Extract the year and month from the ORDER_DATE
    EXTRACT(YEAR FROM f.ORDER_DATE) AS year,
    EXTRACT(MONTH FROM f.ORDER_DATE) AS month,
    SUM(f.REVENUE_USD) AS total_revenue_usd
  FROM 
    SCREENING_BI.FREIGHT.FILES f  -- Using the Files table from the given database schema
  LEFT JOIN 
    SCREENING_BI.FREIGHT.CUSTOMERS c
    ON f.CUSTOMER_ID = c.CUSTOMER_ID
  LEFT JOIN 
    SCREENING_BI.FREIGHT.CONTAINERS cn
    ON f.GLOBAL_FILE_ID = cn.GLOBAL_FILE_ID
  WHERE
    f.ORDER_DATE IS NOT NULL  -- Make sure ORDER_DATE is valid
  GROUP BY
    year, month
)

-- Final select to display monthly and yearly revenue
SELECT
  year,
  month,
  total_revenue_usd
FROM
  revenue_data
ORDER BY
  year DESC, month DESC;


// Year over Year Revenue growth 
-- models/revenue_yoy_growth.sql


WITH yearly_revenue AS (
  -- Step 1: Calculate total revenue for each year
  SELECT
    EXTRACT(YEAR FROM f.ORDER_DATE) AS year,
    ROUND(SUM(f.REVENUE_USD) / 1000000000, 2) AS total_revenue_usd_in_billions  -- Convert to billions and round to 2 decimals
  FROM
    SCREENING_BI.FREIGHT.FILES f
  LEFT JOIN
    SCREENING_BI.FREIGHT.CUSTOMERS c
    ON f.CUSTOMER_ID = c.CUSTOMER_ID
  LEFT JOIN
    SCREENING_BI.FREIGHT.CONTAINERS cn
    ON f.GLOBAL_FILE_ID = cn.GLOBAL_FILE_ID
  WHERE
    f.ORDER_DATE IS NOT NULL  -- Filter to only include records with valid order dates
  GROUP BY
    year
),

-- Step 2: Combine the current and previous year's revenue for YoY calculation
revenue_with_previous_year AS (
  SELECT
    current_year.year,
    current_year.total_revenue_usd_in_billions AS current_year_revenue,
    previous_year.total_revenue_usd_in_billions AS previous_year_revenue
  FROM
    yearly_revenue current_year
  LEFT JOIN
    yearly_revenue previous_year
    ON current_year.year = previous_year.year + 1  -- Join to get previous year's data
)

-- Step 3: Calculate Year-over-Year (YoY) Growth in percentage and round the results
SELECT
  year,
  current_year_revenue,
  previous_year_revenue,
  CASE
    WHEN previous_year_revenue IS NULL THEN NULL
    ELSE ROUND((current_year_revenue - previous_year_revenue) / NULLIF(previous_year_revenue, 0) * 100, 2)  -- Round the YoY growth percentage to 2 decimals
  END AS yoy_growth_percentage
FROM
  revenue_with_previous_year
ORDER BY
  year DESC;


  // Customer retention rate 
 WITH active_customers_year AS (
    -- Get the active customers for a given year
    SELECT 
        CUSTOMER_ID,
        EXTRACT(YEAR FROM ORDER_DATE) AS order_year
    FROM 
        SCREENING_BI.FREIGHT.FILES
    GROUP BY 
        CUSTOMER_ID, EXTRACT(YEAR FROM ORDER_DATE)
),
retained_customers AS (
    -- Get the customers who were active in both the current and previous years
    SELECT 
        a.CUSTOMER_ID,
        a.order_year AS current_year,
        a.order_year - 1 AS previous_year
    FROM 
        active_customers_year a
    INNER JOIN 
        active_customers_year b
    ON 
        a.CUSTOMER_ID = b.CUSTOMER_ID 
        AND a.order_year = b.order_year + 1
),
previous_year_customers AS (
    -- Get the count of active customers in the previous year
    SELECT 
        order_year AS previous_year,
        COUNT(DISTINCT CUSTOMER_ID) AS previous_year_customers_count
    FROM 
        active_customers_year
    GROUP BY 
        order_year
)
-- Calculate the retention rate and include previous year customers
SELECT 
    r.current_year,
    COALESCE(p.previous_year_customers_count, 0) AS previous_year_customers,
    COUNT(DISTINCT r.CUSTOMER_ID) AS retained_customers_count,
    ROUND(COUNT(DISTINCT r.CUSTOMER_ID) * 100.0 / COALESCE(p.previous_year_customers_count, 1), 2) AS CRR_percentage
FROM 
    retained_customers r
LEFT JOIN 
    previous_year_customers p 
ON 
    r.previous_year = p.previous_year
GROUP BY 
    r.current_year, p.previous_year_customers_count
ORDER BY 
    r.current_year;

// On time delivery rate 
SELECT
    EXTRACT(YEAR FROM ORDER_DATE) AS delivery_year, 
    ROUND(
        (COUNT(CASE WHEN DELIVERY_DATE <= REQUESTED_DELIVERY_DATE THEN 1 END) * 100.0) / 
        COUNT(DELIVERY_DATE), 2
    ) AS on_time_delivery_rate
FROM 
    SCREENING_BI.FREIGHT.FILES
WHERE 
    DELIVERY_DATE IS NOT NULL
GROUP BY
    EXTRACT(YEAR FROM ORDER_DATE)
ORDER BY 
    delivery_year;


/// Cost per shipment 
WITH yearly_costs AS (
    -- Calculate the Cost per Shipment for each year
    SELECT
        EXTRACT(YEAR FROM f.ORDER_DATE) AS year,
        ROUND(
            SUM(f.REVENUE_USD) / COUNT(f.DELIVERY_DATE), 2
        ) AS cost_per_shipment
    FROM 
        SCREENING_BI.FREIGHT.FILES f
    WHERE 
        f.DELIVERY_DATE IS NOT NULL  -- Only consider completed deliveries
    GROUP BY 
        EXTRACT(YEAR FROM f.ORDER_DATE)
)
SELECT 
    year,
    cost_per_shipment,
    LAG(cost_per_shipment) OVER (ORDER BY year) AS previous_year_cost_per_shipment,
    ROUND(
        (cost_per_shipment - LAG(cost_per_shipment) OVER (ORDER BY year)) * 100.0 / 
        LAG(cost_per_shipment) OVER (ORDER BY year), 2
    ) AS yoy_change_percentage
FROM 
    yearly_costs
ORDER BY 
    year;


// Container Utilisation Rate
WITH yearly_utilization AS (
    -- Calculate the Used Container Capacity and Container Utilization Rate for each year
    SELECT
        EXTRACT(YEAR FROM f.ORDER_DATE) AS year,
        ROUND(
            SUM(c.TEU) / (COUNT(c.CONTAINER_ID) * 100), 2  -- Assuming 100 TEU per container as total capacity
        ) AS container_utilization_rate
    FROM 
        SCREENING_BI.FREIGHT.FILES f
    JOIN 
        SCREENING_BI.FREIGHT.CONTAINERS c
    ON 
        f.GLOBAL_FILE_ID = c.GLOBAL_FILE_ID  -- Assuming GLOBAL_FILE_ID links the files to containers
    WHERE 
        f.DELIVERY_DATE IS NOT NULL
    GROUP BY 
        EXTRACT(YEAR FROM f.ORDER_DATE)
)
SELECT 
    year,
    container_utilization_rate,
    LAG(container_utilization_rate) OVER (ORDER BY year) AS previous_year_utilization_rate,
    ROUND(
        (container_utilization_rate - LAG(container_utilization_rate) OVER (ORDER BY year)) * 100.0 / 
        LAG(container_utilization_rate) OVER (ORDER BY year), 2
    ) AS yoy_change_percentage
FROM 
    yearly_utilization
ORDER BY 
    year;



// Profit Margin
WITH yearly_profit_margin AS (
    -- Calculate Profit Margin for each year
    SELECT
        EXTRACT(YEAR FROM f.ORDER_DATE) AS year,
        ROUND(
            (SUM(f.NET_REVENUE_USD) / SUM(f.REVENUE_USD)) * 100, 2
        ) AS profit_margin
    FROM 
        SCREENING_BI.FREIGHT.FILES f
    WHERE 
        f.DELIVERY_DATE IS NOT NULL
    GROUP BY 
        EXTRACT(YEAR FROM f.ORDER_DATE)
)
SELECT 
    year,
    profit_margin,
    LAG(profit_margin) OVER (ORDER BY year) AS previous_year_profit_margin,
    ROUND(
        (profit_margin - LAG(profit_margin) OVER (ORDER BY year)) * 100.0 / 
        LAG(profit_margin) OVER (ORDER BY year), 2
    ) AS yoy_change_percentage
FROM 
    yearly_profit_margin
ORDER BY 
    year;


// Shipment Volume by Destination
WITH yearly_shipment_volume AS (
    -- Calculate the shipment volume for each destination and year
    SELECT
        EXTRACT(YEAR FROM f.ORDER_DATE) AS year,
        f.DESTINATION_COUNTRY,
        COUNT(f.GLOBAL_FILE_ID) AS shipment_volume
    FROM 
        SCREENING_BI.FREIGHT.FILES f
    WHERE 
        f.DELIVERY_DATE IS NOT NULL -- Only consider completed deliveries
    GROUP BY 
        EXTRACT(YEAR FROM f.ORDER_DATE), f.DESTINATION_COUNTRY
)
SELECT 
    year,
    DESTINATION_COUNTRY,
    shipment_volume,
    LAG(shipment_volume) OVER (PARTITION BY DESTINATION_COUNTRY ORDER BY year) AS previous_year_shipment_volume,
    ROUND(
        (shipment_volume - LAG(shipment_volume) OVER (PARTITION BY DESTINATION_COUNTRY ORDER BY year)) * 100.0 / 
        LAG(shipment_volume) OVER (PARTITION BY DESTINATION_COUNTRY ORDER BY year), 2
    ) AS yoy_change_percentage
FROM 
    yearly_shipment_volume
ORDER BY 
    DESTINATION_COUNTRY, year;


    // Top 5 countries Shipment yoy
   WITH yearly_shipment_volume AS (
    -- Calculate the shipment volume for each destination and year
    SELECT
        EXTRACT(YEAR FROM f.ORDER_DATE) AS year,
        f.DESTINATION_COUNTRY,
        COUNT(f.GLOBAL_FILE_ID) AS shipment_volume
    FROM 
        SCREENING_BI.FREIGHT.FILES f
    WHERE 
        f.DELIVERY_DATE IS NOT NULL -- Only consider completed deliveries
        AND f.DESTINATION_COUNTRY IS NOT NULL -- Exclude rows with NULL destination countries
    GROUP BY 
        EXTRACT(YEAR FROM f.ORDER_DATE), f.DESTINATION_COUNTRY
),
ranked_shipment_volume AS (
    -- Rank the destinations based on shipment volume for each year
    SELECT 
        year,
        DESTINATION_COUNTRY,
        shipment_volume,
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY shipment_volume DESC) AS rank
    FROM 
        yearly_shipment_volume
)
SELECT 
    year,
    DESTINATION_COUNTRY,
    shipment_volume,
    LAG(shipment_volume) OVER (PARTITION BY DESTINATION_COUNTRY ORDER BY year) AS previous_year_shipment_volume,
    ROUND(
        (shipment_volume - LAG(shipment_volume) OVER (PARTITION BY DESTINATION_COUNTRY ORDER BY year)) * 100.0 / 
        LAG(shipment_volume) OVER (PARTITION BY DESTINATION_COUNTRY ORDER BY year), 2
    ) AS yoy_change_percentage
FROM 
    ranked_shipment_volume
WHERE 
    rank <= 5 -- Only show the top 5 destinations
ORDER BY 
    year, shipment_volume DESC;



