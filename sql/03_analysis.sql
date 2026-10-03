-- Step 3: analysis queries behind the dashboard and findings.
-- Run: sqlite3 -header -column data/superstore.db < sql/03_analysis.sql

.print '== KPIs =='
SELECT ROUND(SUM(sales),0) AS revenue, ROUND(SUM(profit),0) AS profit,
       ROUND(100.0*SUM(profit)/SUM(sales),1) AS margin_pct,
       COUNT(DISTINCT order_id) AS orders, COUNT(DISTINCT customer_id) AS customers
FROM orders;

.print '== Revenue & profit by year =='
SELECT order_year, ROUND(SUM(sales),0) AS revenue, ROUND(SUM(profit),0) AS profit,
       ROUND(100.0*SUM(profit)/SUM(sales),1) AS margin_pct
FROM orders GROUP BY order_year;

.print '== Region =='
SELECT region, region_manager, ROUND(SUM(sales),0) AS revenue, ROUND(SUM(profit),0) AS profit,
       ROUND(100.0*SUM(profit)/SUM(sales),1) AS margin_pct, ROUND(AVG(discount)*100,1) AS avg_discount_pct
FROM orders GROUP BY region ORDER BY revenue DESC;

.print '== Discount band vs margin =='
SELECT discount_band, COUNT(*) AS lines, ROUND(SUM(sales),0) AS revenue, ROUND(SUM(profit),0) AS profit,
       ROUND(100.0*SUM(profit)/SUM(sales),1) AS margin_pct
FROM orders GROUP BY discount_band ORDER BY MIN(discount);

.print '== Central region: states by profit (discount policy) =='
SELECT state, ROUND(SUM(sales),0) AS revenue, ROUND(SUM(profit),0) AS profit,
       ROUND(AVG(discount)*100,1) AS avg_discount_pct
FROM orders WHERE region='Central' GROUP BY state ORDER BY profit;

.print '== Worst states overall =='
SELECT state, region, ROUND(SUM(sales),0) AS revenue, ROUND(SUM(profit),0) AS profit,
       ROUND(AVG(discount)*100,1) AS avg_discount_pct
FROM orders GROUP BY state ORDER BY profit LIMIT 6;

.print '== Sub-category profit =='
SELECT category, sub_category, ROUND(SUM(sales),0) AS revenue, ROUND(SUM(profit),0) AS profit,
       ROUND(100.0*SUM(profit)/SUM(sales),1) AS margin_pct, ROUND(AVG(discount)*100,1) AS avg_discount_pct
FROM orders GROUP BY sub_category ORDER BY profit;

.print '== Tables/Bookcases/Machines: discounted vs not =='
SELECT sub_category, CASE WHEN discount>0 THEN 'discounted' ELSE 'full price' END AS price,
       COUNT(*) AS lines, ROUND(SUM(sales),0) AS revenue, ROUND(SUM(profit),0) AS profit
FROM orders WHERE sub_category IN ('Tables','Bookcases','Supplies','Machines')
GROUP BY 1,2 ORDER BY 1,2;

.print '== Top 10 products by revenue =='
SELECT product_name, sub_category, ROUND(SUM(sales),0) AS revenue, ROUND(SUM(profit),0) AS profit
FROM orders GROUP BY product_name ORDER BY revenue DESC LIMIT 10;

.print '== Seasonality: avg share of annual revenue by month =='
SELECT substr(order_month,6,2) AS month, ROUND(100.0*SUM(sales)/(SELECT SUM(sales) FROM orders),1) AS pct_of_revenue
FROM orders GROUP BY month ORDER BY month;

.print '== Returns by region =='
SELECT o.region, COUNT(DISTINCT o.order_id) AS orders,
       COUNT(DISTINCT CASE WHEN is_returned=1 THEN o.order_id END) AS returned,
       ROUND(100.0*COUNT(DISTINCT CASE WHEN is_returned=1 THEN o.order_id END)/COUNT(DISTINCT o.order_id),1) AS return_rate_pct
FROM orders o GROUP BY o.region ORDER BY return_rate_pct DESC;
