
-- PostgreSQL Data Export and Import Script

-- Export table to CSV (run from psql or pgAdmin)
\COPY my_table TO 'my_table_export.csv' WITH (FORMAT CSV, HEADER);

-- Import table from CSV (ensure table exists and matches schema)
\COPY my_table FROM 'my_table_export.csv' WITH (FORMAT CSV, HEADER);
