"""Tests zur Standardbibliothek. Aufruf: python3 -m tests.test_reports"""

from __future__ import annotations

from ledger.model import all_entries, euro
from ledger.reports import monthly_totals


def check(label: str, got, want) -> bool:
    ok = got == want
    print(f"{'ok  ' if ok else 'FAIL'} {label}: {got!r}" + ("" if ok else f" != {want!r}"))
    return ok


def main() -> int:
    results = [
        check("Anzahl Buchungen", len(all_entries()), 10),
        check("erste Buchung", all_entries()[0].entry_id, "E-0001"),
        check("euro positiv", euro(1_420_000), "14.200,00"),
        check("euro negativ", euro(-63_450), "-634,50"),
        check("euro null", euro(0), "0,00"),
        check("Monate", list(monthly_totals()), ["2026-06", "2026-07"]),
        check("Saldo Juni", monthly_totals()["2026-06"]["balance"], -7_067_450),
        check("Ertrag Juli", monthly_totals()["2026-07"]["income"], 1_660_000),
    ]
    failed = results.count(False)
    print(f"\n{len(results) - failed}/{len(results)} Pruefungen bestanden")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
