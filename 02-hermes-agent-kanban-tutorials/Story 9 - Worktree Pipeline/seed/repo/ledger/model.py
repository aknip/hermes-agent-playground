"""Datensatz und In-Memory-Speicher des Hauptbuchs."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date


@dataclass(frozen=True)
class Entry:
    """Eine Buchung."""

    entry_id: str
    booked_on: date
    account: str
    description: str
    amount_cents: int      # positiv = Ertrag, negativ = Aufwand
    cost_centre: str


SAMPLE: list[Entry] = [
    Entry("E-0001", date(2026, 6, 3),  "4000", "Projekt Seehafen, Rate 1",  1_420_000, "PRJ-SEE"),
    Entry("E-0002", date(2026, 6, 5),  "6300", "Hosting Juni",                -184_000, "BETRIEB"),
    Entry("E-0003", date(2026, 6, 11), "6000", "Gehaelter Juni",           -9_120_000, "PERSONAL"),
    Entry("E-0004", date(2026, 6, 18), "4000", "Projekt Moorbach, Rate 3",    880_000, "PRJ-MOO"),
    Entry("E-0005", date(2026, 6, 30), "6800", "Reisekosten Juni",             -63_450, "PRJ-SEE"),
    Entry("E-0006", date(2026, 7, 2),  "4000", "Projekt Seehafen, Rate 2",  1_420_000, "PRJ-SEE"),
    Entry("E-0007", date(2026, 7, 5),  "6300", "Hosting Juli",                -184_000, "BETRIEB"),
    Entry("E-0008", date(2026, 7, 11), "6000", "Gehaelter Juli",           -9_340_000, "PERSONAL"),
    Entry("E-0009", date(2026, 7, 22), "4000", "Wartung Birkholz",            240_000, "PRJ-BIR"),
    Entry("E-0010", date(2026, 7, 29), "6800", "Reisekosten Juli",            -21_900, "PRJ-MOO"),
]


def all_entries() -> list[Entry]:
    """Alle Buchungen, aufsteigend nach Datum."""
    return sorted(SAMPLE, key=lambda e: (e.booked_on, e.entry_id))


def euro(cents: int) -> str:
    """Centbetrag als deutscher Eurobetrag: -9_120_000 -> '-91.200,00'."""
    sign = "-" if cents < 0 else ""
    whole, rest = divmod(abs(cents), 100)
    return f"{sign}{whole:,}".replace(",", ".") + f",{rest:02d}"
