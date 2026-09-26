# SettleSync — Gateway–Ledger Reconciliation (Databricks + Snowflake)

**ExcelR x KIIT Capstone | Finance & Fintech | Topic 10: "Reconciliation — Two Systems, One Truth"**

A payment gateway and a finance ledger record the same month of transactions independently.
Netting their totals shows a gap of only 15 — but that hides 208 gateway-only transactions,
193 ledger-only transactions, and 450 that exist on both sides with a mismatched amount.
This project builds an automated Bronze → Silver → Snowflake pipeline that replaces the
misleading net figure with a full, reasoned break list.

## Results

| Check | Value |
|---|---|
| Bronze rows (gateway / ledger) | 41,468 / 41,323 |
| Silver rows after de-dup (gateway / ledger) | 41,208 / 41,193 |
| Gateway-only transactions | 208 |
| Ledger-only transactions | 193 |
| Unreadable ('NA') gateway amounts | 350 |
| Amount mismatches (tolerance ₹0.05) | 450 |
| Total reconciled rows | 41,401 |
| Reconciliation query runtime | 64 ms (X-Small warehouse) |

## Architecture

```
Gateway CSV ──┐                                              ┌─ SILVER_GATEWAY ─┐
              ├─▶ Bronze (raw, all-string) ─▶ Silver (clean, ─┤                  ├─▶ CSV ─▶ Snowflake
Ledger CSV  ──┘   two separate tables         deduped, typed) └─ SILVER_LEDGER  ─┘   stage    (COPY INTO)
                                                                                          │
                                                                                          ▼
                                                              FULL OUTER JOIN reconciliation SQL
                                                              (gateway_only / ledger_only / amount_mismatch /
                                                               gross_break / net_break, per settlement day)
```

## Tech stack

- **Databricks** — PySpark, Delta Lake (Bronze / Silver layers)
- **Snowflake** — SQL, X-Small virtual warehouse (reconciliation + reporting)
- **Python 3** — data generation and transformation
- **SQL** — reconciliation logic (`FULL OUTER JOIN`, `COUNT_IF`, `COALESCE`)

## Repository structure

```
├── notebooks/
│   ├── 01_bronze_ingest.py        # Land raw gateway & ledger extracts, unchanged, as Delta
│   ├── 02_silver_clean.py         # Trim keys, try_cast amounts, dedupe, log decisions
│   └── 03_export_to_snowflake.py  # Write Silver tables to CSV in the Volume, stage, COPY INTO
├── sql/
│   └── 01_captsone_project.sql    # Snowflake reconciliation & break-report queries
├── docs/
│   └── SettleSync_Capstone_Project_Report.pdf
├── screenshots/
│   ├── daily_break_report.png
│   └── monthly_totals_check.png
└── README.md
```

## How to run

1. In Databricks, set `MY_ID` and `VOL` at the top of the first notebook, then create the
   catalog/schema/Volume referenced by `VOL`.
2. Run `01_bronze_ingest.py` to land the raw gateway and ledger files as two separate,
   untouched Bronze Delta tables.
3. Run `02_silver_clean.py` to trim keys, `try_cast` amounts, and de-duplicate on `txn_id`.
4. Run `03_export_to_snowflake.py` to write `SILVER_GATEWAY` / `SILVER_LEDGER` to CSV in the
   Volume, upload to a Snowflake stage, and `COPY INTO` the Snowflake tables.
5. In Snowflake, run `sql/01_captsone_project.sql` to produce the daily break report and the
   monthly totals check.

## Notes

- No credentials, API keys, or tokens are committed to this repository — Databricks reads
  Snowflake credentials from a secret scope at run time.
- The full write-up, methodology, and screenshots are in `docs/SettleSync_Capstone_Project_Report.pdf`.

## Author

Musarraf Khan — ExcelR x KIIT Capstone, 2026
