-- Grant USAGE on the database and schema
GRANT USAGE ON DATABASE SCREENING_BI TO priya_sankar;
GRANT USAGE ON SCHEMA SCREENING_BI.FREIGHT TO USER priya_sankar;

-- Grant SELECT, CREATE privileges on all tables and views in the schema
GRANT CREATE, SELECT ON ALL TABLES IN SCHEMA SCREENING_BI.FREIGHT TO USER priya_sankar;

-- If you're working with views, grant the appropriate privileges
GRANT CREATE VIEW ON SCHEMA SCREENING_BI.FREIGHT TO USER priya_sankar;

-- Grant the necessary privileges to manage the warehouse (if applicable)
GRANT USAGE ON WAREHOUSE <your_warehouse> TO USER priya_sankar;
