"""
Bake the UDS benchmark marts into one static HTML page (uds_benchmarks/dashboard/site/index.html).
No server, no BI license, no warehouse to keep running: GitHub Pages hosts it for free and
it never expires.

    python uds_benchmarks/dashboard/build.py
"""
import json
from datetime import date
from pathlib import Path

import duckdb

HERE = Path(__file__).resolve().parent
WAREHOUSE = HERE.parent / "data" / "uds.duckdb"
TEMPLATE = HERE / "template.html"
OUT = HERE / "site" / "index.html"

BANDS = ["Top quarter of peers", "Above peer median", "Below peer median",
         "Bottom quarter of peers", "Too few patients to benchmark"]


def q(con, sql):
    cur = con.execute(sql)
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def r(x, n=6):  # 6 places: rounding once, in the browser, avoids double-rounding (0.45947 -> 45.9%, not 46.0%)
    return None if x is None else round(float(x), n)


def main():
    con = duckdb.connect(str(WAREHOUSE), read_only=True)
    measures = q(con, """select measure_id, measure_name, short_name, ecqm_id, domain, higher_is_better, first_year
                         from main.uds_measures order by domain, short_name""")
    years = [row["y"] for row in q(con, "select distinct reporting_year as y from main.mart_uds_center_benchmarks order by 1")]
    latest = max(years)

    # one entry per health center (latest year's name and location)
    centers = q(con, f"""
        select bhcmisid, health_center_name, city, state
        from main.stg_uds__health_centers
        qualify row_number() over (partition by bhcmisid order by reporting_year desc) = 1
        order by state, health_center_name""")
    idx = {c["bhcmisid"]: i for i, c in enumerate(centers)}
    profile = q(con, """
        select h.reporting_year, h.bhcmisid, pg.peer_group, pm.total_patients, pm.pct_uninsured, pm.pct_medicaid_chip
        from main.stg_uds__health_centers h
        left join main.int_uds__peer_groups pg using (reporting_year, bhcmisid)
        left join main.stg_uds__patient_mix pm using (reporting_year, bhcmisid)""")
    peer_groups = sorted({p["peer_group"] for p in profile if p["peer_group"]})
    pg_idx = {g: i for i, g in enumerate(peer_groups)}

    # compact rows: [center, rate, denominator, peer_median, national_percentile, band, patients_to_peer_median]
    results = {}
    for row in q(con, """
            select reporting_year, measure_id, bhcmisid, rate, denominator, peer_median,
                   national_percentile, peer_band, patients_to_peer_median
            from main.mart_uds_center_benchmarks where rate is not null"""):
        results.setdefault(row["measure_id"], {}).setdefault(str(row["reporting_year"]), []).append([
            idx[row["bhcmisid"]], r(row["rate"]), int(row["denominator"] or 0), r(row["peer_median"]),
            r(row["national_percentile"], 1), BANDS.index(row["peer_band"]), row["patients_to_peer_median"]])

    data = {
        "measures": measures,
        "years": years,
        "latest": latest,
        "centers": [[c["health_center_name"], c["city"], c["state"]] for c in centers],
        "peer_groups": peer_groups,
        "profile": {str(y): {} for y in years},
        "bands": BANDS,
        "results": results,
        "national": q(con, "select reporting_year, measure_id, weighted_rate, median_center_rate, centers from main.mart_uds_national_trend"),
        "states": q(con, "select reporting_year, state, measure_id, weighted_rate, centers from main.mart_uds_state_measures"),
        "gradient": q(con, "select reporting_year, measure_id, uninsured_quintile, min_pct_uninsured, max_pct_uninsured, centers, weighted_rate from main.mart_uds_uninsured_gradient"),
        "quality": q(con, "select reporting_year, check_order, check_name, value from main.mart_uds_data_quality order by reporting_year, check_order"),
        "built_on": date.today().isoformat(),
    }
    for p in profile:
        data["profile"][str(p["reporting_year"])][idx[p["bhcmisid"]]] = [
            pg_idx.get(p["peer_group"]), int(p["total_patients"] or 0), r(p["pct_uninsured"], 3), r(p["pct_medicaid_chip"], 3)]
    for key in ("national", "states", "gradient"):
        for row in data[key]:
            for k, v in row.items():
                if isinstance(v, float):
                    row[k] = r(v)
    con.close()

    payload = json.dumps(data, separators=(",", ":"), default=float).replace("</", "<\\/")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(TEMPLATE.read_text().replace("/*__DATA__*/null", payload))
    print(f"wrote {OUT.relative_to(HERE.parent.parent)}  ({len(centers):,} health centers, "
          f"{len(measures)} measures, {len(years)} years, {OUT.stat().st_size / 1024:,.0f} KB)")


if __name__ == "__main__":
    main()
