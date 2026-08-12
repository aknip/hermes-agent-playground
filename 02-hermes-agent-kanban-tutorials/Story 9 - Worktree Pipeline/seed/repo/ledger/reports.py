"""Vorhandene Berichte. Stilvorlage fuer neue Auswertungen."""

from __future__ import annotations

from collections import OrderedDict

from .model import Entry, all_entries, euro


def monthly_totals(entries: list[Entry] | None = None) -> "OrderedDict[str, dict]":
    """Ertrag, Aufwand und Saldo je Monat, chronologisch.

    Rueckgabe: {"2026-06": {"income": …, "expense": …, "balance": …}, …}
    Alle Werte in Cent.
    """
    rows: "OrderedDict[str, dict]" = OrderedDict()
    for entry in entries if entries is not None else all_entries():
        key = entry.booked_on.strftime("%Y-%m")
        bucket = rows.setdefault(key, {"income": 0, "expense": 0, "balance": 0})
        if entry.amount_cents >= 0:
            bucket["income"] += entry.amount_cents
        else:
            bucket["expense"] += entry.amount_cents
        bucket["balance"] += entry.amount_cents
    return rows


def render_monthly_totals(entries: list[Entry] | None = None) -> str:
    """Monatssummen als Textblock — was die Oberflaeche heute anzeigt."""
    lines = [f"{'Monat':<9}{'Ertrag':>14}{'Aufwand':>14}{'Saldo':>14}"]
    for month, row in monthly_totals(entries).items():
        lines.append(
            f"{month:<9}{euro(row['income']):>14}"
            f"{euro(row['expense']):>14}{euro(row['balance']):>14}"
        )
    return "\n".join(lines)
