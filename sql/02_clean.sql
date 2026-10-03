-- Step 2: clean staged data into analysis-ready tables.
-- Run: sqlite3 data/superstore.db < sql/02_clean.sql

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS people;
DROP TABLE IF EXISTS returns;

-- People: regional managers (4 rows, already clean; just trim)
CREATE TABLE people AS
SELECT TRIM("Person") AS manager, TRIM("Region") AS region
FROM stg_people;

-- Returns: source has one row per returned LINE, so Order IDs repeat.
-- Deduplicate to one row per returned order (800 rows -> 296 orders).
CREATE TABLE returns AS
SELECT DISTINCT TRIM("Order ID") AS order_id
FROM stg_returns
WHERE TRIM("Returned") = 'Yes';

-- Orders
CREATE TABLE orders AS
WITH parsed AS (
  SELECT
    CAST("Row ID" AS INTEGER)                    AS row_id,
    TRIM("Order ID")                             AS order_id,
    -- M/D/YYYY text -> ISO date (YYYY-MM-DD)
    printf('%04d-%02d-%02d',
      CAST(substr("Order Date", instr(substr("Order Date", instr("Order Date",'/')+1),'/') + instr("Order Date",'/') + 1) AS INTEGER),
      CAST(substr("Order Date", 1, instr("Order Date",'/')-1) AS INTEGER),
      CAST(substr("Order Date", instr("Order Date",'/')+1,
           instr(substr("Order Date", instr("Order Date",'/')+1),'/')-1) AS INTEGER)) AS order_date,
    printf('%04d-%02d-%02d',
      CAST(substr("Ship Date", instr(substr("Ship Date", instr("Ship Date",'/')+1),'/') + instr("Ship Date",'/') + 1) AS INTEGER),
      CAST(substr("Ship Date", 1, instr("Ship Date",'/')-1) AS INTEGER),
      CAST(substr("Ship Date", instr("Ship Date",'/')+1,
           instr(substr("Ship Date", instr("Ship Date",'/')+1),'/')-1) AS INTEGER)) AS ship_date,
    TRIM("Ship Mode")       AS ship_mode,
    TRIM("Customer ID")     AS customer_id,
    TRIM("Customer Name")   AS customer_name,
    TRIM("Segment")         AS segment,
    TRIM("City")            AS city,
    TRIM("State")           AS state,
    -- Excel dropped leading zeros on New England ZIPs (e.g. 2149 -> 02149);
    -- Burlington, VT rows have no ZIP at all -> 05401.
    CASE
      WHEN TRIM("Postal Code") = '' AND TRIM("City") = 'Burlington' AND TRIM("State") = 'Vermont' THEN '05401'
      WHEN TRIM("Postal Code") = '' THEN NULL
      ELSE substr('00000' || TRIM("Postal Code"), -5)
    END                     AS postal_code,
    TRIM("Region")          AS region,
    TRIM("Product ID")      AS product_id,
    TRIM("Category")        AS category,
    TRIM("Sub-Category")    AS sub_category,
    TRIM("Product Name")    AS product_name,
    ROUND(CAST("Sales" AS REAL), 4)    AS sales,
    CAST("Quantity" AS INTEGER)        AS quantity,
    ROUND(CAST("Discount" AS REAL), 2) AS discount,
    ROUND(CAST("Profit" AS REAL), 4)   AS profit
  FROM stg_orders
  WHERE TRIM("Order ID") <> ''          -- drop any blank lines
)
SELECT
  p.*,
  CAST(strftime('%Y', order_date) AS INTEGER)            AS order_year,
  strftime('%Y-%m', order_date)                          AS order_month,
  CAST(julianday(ship_date) - julianday(order_date) AS INTEGER) AS days_to_ship,
  CASE
    WHEN discount = 0    THEN '0%'
    WHEN discount <= 0.1 THEN '1-10%'
    WHEN discount <= 0.2 THEN '11-20%'
    WHEN discount <= 0.3 THEN '21-30%'
    WHEN discount <= 0.5 THEN '31-50%'
    ELSE '>50%'
  END                                                    AS discount_band,
  CASE WHEN r.order_id IS NOT NULL THEN 1 ELSE 0 END     AS is_returned,
  m.manager                                              AS region_manager
FROM parsed p
LEFT JOIN returns r ON r.order_id = p.order_id
LEFT JOIN people  m ON m.region  = p.region;

-- ---------- Data-quality checks (should all print 0 / expected) ----------
SELECT 'rows (expect 9994)',            COUNT(*) FROM orders;
SELECT 'duplicate row_id',              COUNT(*) - COUNT(DISTINCT row_id) FROM orders;
SELECT 'bad dates',                     COUNT(*) FROM orders WHERE date(order_date) IS NULL OR date(ship_date) IS NULL;
SELECT 'ship before order',             COUNT(*) FROM orders WHERE days_to_ship < 0;
SELECT 'null postal codes',             COUNT(*) FROM orders WHERE postal_code IS NULL;
SELECT 'negative sales/qty',            COUNT(*) FROM orders WHERE sales <= 0 OR quantity <= 0;
SELECT 'discount out of [0,1]',         COUNT(*) FROM orders WHERE discount < 0 OR discount > 1;
SELECT 'rows with no region manager',   COUNT(*) FROM orders WHERE region_manager IS NULL;
SELECT 'returned orders (distinct)',    COUNT(*) FROM returns;
SELECT 'returns not matched to orders', COUNT(*) FROM returns WHERE order_id NOT IN (SELECT order_id FROM orders);
SELECT 'date range', MIN(order_date) || ' to ' || MAX(order_date) FROM orders;
