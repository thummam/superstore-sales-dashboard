"""Step 1: load the raw CSV into SQLite staging tables, untouched (all TEXT).

The source file is really three Excel sheets stacked into one CSV:
  rows 1-9994   -> Orders
  'Person,Region' header + 4 rows -> People (regional managers)
  'Returned,Order ID' header + 800 rows -> Returns
We split on those embedded header lines and stage each as-is; every
cleaning rule lives in 02_clean.sql so it can be reviewed as SQL.
"""
import csv
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw_superstore.csv"
DB = ROOT / "data" / "superstore.db"

with open(RAW, newline="", encoding="utf-8") as f:
    rows = list(csv.reader(f))

orders_header, sections, current = rows[0], {"orders": []}, "orders"
for r in rows[1:]:
    if r[:2] == ["Person", "Region"]:
        current = "people"; sections[current] = []; continue
    if r[:2] == ["Returned", "Order ID"]:
        current = "returns"; sections[current] = []; continue
    sections[current].append(r if current == "orders" else r[:2])

DB.unlink(missing_ok=True)
con = sqlite3.connect(DB)
cols = ", ".join(f'"{c}" TEXT' for c in orders_header)
con.execute(f"CREATE TABLE stg_orders ({cols})")
con.executemany(f"INSERT INTO stg_orders VALUES ({','.join('?' * len(orders_header))})", sections["orders"])
con.execute('CREATE TABLE stg_people ("Person" TEXT, "Region" TEXT)')
con.executemany("INSERT INTO stg_people VALUES (?, ?)", sections["people"])
con.execute('CREATE TABLE stg_returns ("Returned" TEXT, "Order ID" TEXT)')
con.executemany("INSERT INTO stg_returns VALUES (?, ?)", sections["returns"])
con.commit()
for t in ("stg_orders", "stg_people", "stg_returns"):
    print(t, con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0])
