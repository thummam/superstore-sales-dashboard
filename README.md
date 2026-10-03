# Superstore Sales Performance Dashboard

An end-to-end retail analytics project: raw data → SQL cleaning → interactive dashboard → business findings.

**Live dashboard:** https://thummam.github.io/superstore-sales-dashboard/

**Data:** Tableau "Sample – Superstore" (US office-supply retailer, Jan 2015 – Dec 2018, 9,994 order lines). It is the same dataset that is published on Kaggle.
**Tools:** SQL (SQLite) for cleaning and analysis, and Python for loading and export. The dashboard is HTML/SVG, and the clean CSV is ready for Tableau or Power BI.

## Key findings

**1. The Central region is losing money because of discounting in Texas and Illinois.**
Central has the lowest margin of the four regions (7.9%, vs 14.9% in the West). Texas and Illinois give an average discount of 37–39% and lost **$38.3K** between them. The other 11 Central states sell at full price, and every one of them made a profit.
*Recommendation:* limit discounts in TX and IL to 20% or less. If those two states had broken even, Central's margin would rise from 7.9% to about 15.5%.

**2. Any discount above 20% loses money.**
Order lines with a discount above 20% brought in $363K of sales but lost **$135K**. Margin is 29.5% with no discount, 11.6% at 11–20% off, −24.8% at 31–50% off and −119% above 50%. Tables, Bookcases and Machines are profitable at full price (+$46.5K together) but lose $64.3K when discounted.
*Recommendation:* cap discounts at 20%, and require approval for anything deeper on Furniture and Machines.

**3. The West has the highest sales, and it also has 4× the return rate.**
11.7% of West orders are returned, against about 3% in the East, Central and South. The West accounts for 189 of the 296 returned orders (64%), even though it places only 32% of all orders.
*Recommendation:* investigate West fulfilment and product quality, starting with the products that are returned most often.

Also worth knowing: revenue grew 51% from 2015 to 2018 ($484K → $733K), and September, November and December together bring in 43% of each year's revenue.

## Data cleaning (SQL)

| Problem found in the raw file | Fix |
|---|---|
| The CSV is really 3 sheets stacked together: Orders (9,994 rows), People (4) and Returns (800). That added 806 junk rows with blank order fields. | Split the file on the embedded header lines into `orders`, `people` and `returns` tables |
| Returns had one row per returned *line*, so Order IDs repeated (800 rows for 296 orders) | `SELECT DISTINCT` gives one row per returned order |
| Dates were stored as text in M/D/YYYY format | Parsed to ISO `YYYY-MM-DD` |
| 438 New England ZIP codes lost their leading zero (e.g. `2149`) | Left-padded to 5 digits (`02149`) |
| 11 Burlington, VT rows had no ZIP code | Filled with `05401` |
| No return flag, manager or time fields on the orders table | Added `is_returned`, `region_manager`, `order_year`, `order_month`, `days_to_ship` and `discount_band` |

QA checks at the end of `02_clean.sql` all pass: 9,994 rows, no duplicate IDs, no bad dates, no orders shipped before they were placed, no null ZIPs, and every return matches an order.

## Files

```
data/raw_superstore.csv        original download
data/superstore_clean.csv      cleaned, analysis-ready (use this in Tableau / Power BI)
data/superstore.db             SQLite database (stg_*, orders, people, returns)
sql/01_load_raw.py             split the stacked sheets and stage them raw
sql/02_clean.sql               all cleaning rules + QA checks
sql/03_analysis.sql            queries behind every chart and finding
sql/04_export.py               export the clean CSV and build the dashboard
dashboard/superstore_dashboard.html   interactive dashboard (open in any browser)
```

To rebuild from scratch:

```
python3 sql/01_load_raw.py
sqlite3 data/superstore.db < sql/02_clean.sql
sqlite3 -header -column data/superstore.db < sql/03_analysis.sql
python3 sql/04_export.py
```

## Rebuilding the dashboard in Power BI or Tableau

Load `data/superstore_clean.csv`. Every column you need is already cleaned and typed.

**Measures (Power BI DAX)**
```
Revenue      = SUM(orders[sales])
Profit       = SUM(orders[profit])
Margin %     = DIVIDE([Profit], [Revenue])
Orders       = DISTINCTCOUNT(orders[order_id])
Return Rate  = DIVIDE(CALCULATE(DISTINCTCOUNT(orders[order_id]), orders[is_returned] = 1), [Orders])
```
In Tableau, the same calculated fields are `SUM([sales])`, `SUM([profit])/SUM([sales])` and `COUNTD([order_id])`.

**Visuals** (these match the HTML dashboard)
1. KPI cards: Revenue, Profit, Margin %, Orders, Return Rate
2. Line chart: order_month × Revenue and Profit
3. Clustered bar chart: region × Revenue and Profit
4. Bar chart: discount_band × Margin % (sort the bands from 0% to >50%)
5. Bar chart: Top 10 product_name by Revenue (Top N filter)
6. Bar chart: sub_category × Profit, coloured by positive/negative
7. Bar chart: the 10 states with the lowest Profit, with average discount in the tooltip
8. Bar chart: region × Return Rate
9. Slicers: order_year, region, category
