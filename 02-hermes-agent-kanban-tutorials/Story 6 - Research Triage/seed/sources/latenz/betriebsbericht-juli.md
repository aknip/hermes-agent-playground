# Betriebsbericht Juli 2026 — Auszug Meridian 2

- Rate Limit im Ingest steht weiterhin bei 5.000 Events/Minute pro Mandant.
  Es ist ein Schutz der gemeinsamen Ingest-Pipeline und in 2.x nicht
  konfigurierbar.
- Zwei Eskalationen im Juli, beide mit derselben Ursache: Kunde will einen
  historischen Backfill fahren, rechnet die Dauer aus und bricht die Migration
  ab. (Halden Logistics, Alpsteg Handel.)
- Der interaktive Betrieb war unauffaellig; 99,95 % Verfuegbarkeit.

Anmerkung Betrieb: Das Rate Limit ist der einzige Punkt, an dem uns Kunden im
Juli die Migration konkret aufgekuendigt haben. Die Latenz im Alltagsbetrieb
war in keinem Ticket ein Thema.
