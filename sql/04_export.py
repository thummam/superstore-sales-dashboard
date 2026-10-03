"""Step 4: export the cleaned table (for Tableau / Power BI) and build the HTML dashboard."""
import csv
import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
con = sqlite3.connect(ROOT / "data" / "superstore.db")

# 1) Clean CSV: one file to drag into Tableau or Power BI
cur = con.execute("SELECT * FROM orders ORDER BY row_id")
cols = [d[0] for d in cur.description]
with open(ROOT / "data" / "superstore_clean.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(cols)
    w.writerows(cur)

# 2) Compact row data for the dashboard's client-side filtering
rows = con.execute("""
  SELECT order_month, region, category, sub_category, product_name, state, order_id,
         sales, profit, discount_band, is_returned, discount
  FROM orders ORDER BY order_date""").fetchall()
dims = {k: [] for k in ("region", "category", "sub", "product", "state", "band")}
idx = {k: {} for k in dims}

def code(kind, val):
    if val not in idx[kind]:
        idx[kind][val] = len(dims[kind]); dims[kind].append(val)
    return idx[kind][val]

order_idx, packed = {}, []
for m, reg, cat, sub, prod, st, oid, s, p, band, ret, disc in rows:
    o = order_idx.setdefault(oid, len(order_idx))
    packed.append([int(m.replace("-", "")), code("region", reg), code("category", cat),
                   code("sub", sub), code("product", prod), code("state", st), o,
                   round(s, 2), round(p, 2), code("band", band), ret, disc])

data = {"dims": dims, "rows": packed}
tpl = (ROOT / "dashboard" / "template.html").read_text(encoding="utf-8")
out = tpl.replace("/*__DATA__*/null", json.dumps(data, separators=(",", ":")))
(ROOT / "dashboard" / "superstore_dashboard.html").write_text(out, encoding="utf-8")
print("rows", len(packed), "orders", len(order_idx), "html bytes", len(out))
