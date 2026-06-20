# Assumptions and Data Quality Findings

This documents the real issues found while building this pipeline, in the order
they were discovered, with the evidence for each decision.

## 1. Data quality findings (Sales.json)

| Issue | Finding | Action |
|---|---|---|
| `Name`, `Education`, `Occupation` mostly null | 268,449 / 298,246 rows (90%) null | Dropped — too sparse to impute meaningfully, documented rather than fake-filled |
| `OrderDate` is a string | Format `M/D/YYYY` (US-style) | Parsed with `pd.to_datetime(..., format="%m/%d/%Y")` |
| No transaction/order ID in source | Each row is already the lowest grain (one product, one customer, one day) — no field distinguishes repeat purchases | Added a surrogate `Sales_SK` at load time |

## 2. The duplicate-row investigation (most important finding)

**Observed:** `sales_df.duplicated().sum()` → 218,008 of 298,246 rows (73.1%) are
byte-for-byte identical once `Name`/`Education`/`Occupation` are dropped.

**Why this happens:** the source data has no order ID and no time-of-day field.
Two genuinely separate purchases — same customer, same product, same day — produce
identical rows. There's no way to distinguish "5 repeat purchases" from "1 row
appearing 5 times by coincidence" using row content alone.

**Test performed before deciding:**

```python
revenue_keep_all = (df["Quantity"] * df["Net Price"]).sum()        # $83,535,101.76
revenue_if_dedup = (df.drop_duplicates()["Quantity"] * ...).sum()  # $42,644,968.84
# Difference: $40,890,132.92 -- 48.9% of total revenue
```

**Decision:** do **not** deduplicate `Fact_Sales`. Each row is treated as a
distinct, valid sale. This is the single highest-impact decision in the whole
pipeline — an early draft that called `drop_duplicates()` on this table understated
total revenue by roughly half before this was caught.

## 3. Forecast vs Sales granularity mismatch

| | `Fact_Sales` | `Fact_Forecast` |
|---|---|---|
| Grain | One row per transaction | One row per Country × Brand × Year |
| Row count | 298,246 | 33 (3 countries × 11 brands × 1 year) |
| Date detail | Day-level | Year only (2009 exclusively) |
| Product detail | Specific `ProductKey` | `Brand` only |
| Customer detail | Specific `CustomerKey` | `CountryRegion` only |

**Consequence:** `Brand` and `CountryRegion` are non-unique attributes on
`Dim_Products` / `Dim_Customers` — a single brand string matches hundreds of
different products. There is no row-level relationship between `Fact_Forecast` and
either dimension table, so no real foreign key can exist between them.

**First (incorrect) attempt:** modeled `Fact_Forecast` ↔ `Dim_Customers` and
`Fact_Forecast` ↔ `Dim_Products` as **many-to-many** relationships in Power BI.
This caused incorrect fan-out — filtering by one product/customer attribute
returned the same (wrong, inflated or flattened) Forecast total for every row,
and an unrelated "(Blank)" category appeared in visuals.

**Fix:** removed the many-to-many relationships entirely. An intermediate
approach added a small `Dim_Year` bridge table to relate `Fact_Forecast[Year]`
into the model — this was later removed as unnecessary. The final design has:

- **No relationship at all** between `Fact_Forecast` and `Dim_Products`,
  `Dim_Customers`, or `Dim_Date`/`Year`.
- All filtering (by Brand, CountryRegion, and Year) is done purely in DAX using
  `TREATAS()`, which applies a virtual filter from the relevant dimension column
  onto `Fact_Forecast`'s own matching column, without any modeled relationship:

```dax
Total Forecast 2009 =
CALCULATE(
    SUM('dw Fact_Forecast'[Forecast]),
    TREATAS({2009}, 'dw Fact_Forecast'[Year]),
    TREATAS(VALUES('dw Dim_Customers'[CountryRegion]), 'dw Fact_Forecast'[CountryRegion]),
)
```

This keeps the model free of any relationship to `Fact_Forecast` entirely (no
bridge table needed) while still letting Brand/Country/Year slicers and visual
filters apply correctly to Forecast figures.

Sales-vs-Forecast comparisons by Country/Brand are also done in a Matrix visual,
where Power BI aligns rows by matching text values across the two unrelated
tables — no relationship needed there either.

**Because Forecast only has 2009 data**, any comparison against Sales must filter
Sales to 2009 as well:

```dax
Total Sales 2009 = CALCULATE([Total Sales], 'dw Dim_Date'[Year] = 2009)
```


## 4. Color theme

Power BI theme derived from the Orion 360 logo (navy `#1B2A4A`, sky blue
`#6EC6E8`, plus supporting neutrals) — see `powerbi/` for the applied theme.
