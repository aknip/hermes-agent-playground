# skript.md — config-pfade-mehrdeutig (Sprechtext, 7 Folien)

Sprechtext je Folie, 90–150 Woerter. Kein Marketing-Ton, keine Superlative,
keine Emojis. Belegte Aussagen; Unbelegtes steht in faktencheck.md unter
"ungeklaert".

---

## Folie 1 — Welche config.toml gewinnt?

Eine Agenten-Konfiguration kann an mehreren Orten liegen. Die Quellen nennen
bis zu vier gleichnamige Speicherorte: das Home-Verzeichnis, den Projektpfad,
unter WSL eine dritte Datei und unter Windows zusaetzlich den Roaming-Pfad als
vierte Stelle. Alle Kandidaten heissen gleich und koennen sich inhaltlich
unterscheiden. Ein Nutzer im Entwicklerforum, wenzelb, berichtet, er habe drei
Kandidaten gefunden und die Erweiterung nehme nicht die, die er erwarte.
@tnowak schreibt auf X von "zwei Pfaden, einem Namen, keiner Warnung". Die
unmittelbare Konsequenz ist schlicht: Aus eigener Kenntnis ist nicht zu sagen,
welche der Dateien tatsaechlich wirkt. Wer eine Einstellung setzt, weiss nicht,
ob und wo sie greift. Der Schmerz ist nicht ein defektes System, sondern eine
fehlende Aussage darueber, welche Datei gewinnt.

---

## Folie 2 — Der Schaden: Freigabepflicht wird stumm umgangen

Der Mechanismus ist nicht nur verwirrend, er hat Folgen. marek.o beschreibt im
Forum eine echte Situation: Die Freigabepflicht war in der Oberflaeche gesetzt,
in der wirksamen Datei jedoch nicht. Der Agent hat daraufhin in einem
Kundenrepo committet. @tnowak berichtet den gleichen Ablauf: Er hat in der
IDE-Erweiterung "approve required" gesetzt, der Agent schrieb trotzdem ohne
Rueckfrage. Nach zwei Tagen Suche stand fest: Die Erweiterung liest eine andere
config.toml, als die Oberflaeche sie schreibt. Eine Schutzvorgabe des Nutzers
wurde also umgangen, ohne dass eine Stelle gewarnt haette. Der Schaden ist
real und betrifft eine sicherheitsrelevante Absicherung. Beide Berichte sind
Selbstauskunft ohne Artefakte; sie sind im Korpus nicht weiter nachpruefbar,
aber sie zeigen den Mechanismus eines stummen Ignorierens.

---

## Folie 3 — Der Mechanismus

Der Kern des Problems ist, dass Lesen und Schreiben auf verschiedene Pfade
gehen. Die IDE-Oberflaeche schreibt eine config.toml; die Erweiterung laedt
beim Start eine andere. Dadurch fehlen Einstellungen, die die Oberflaeche
setzt, in der effektiv geladenen Datei. Ein Wert wie "approve required", der
in der geschriebenen Datei steht, erreicht den ausfuehrenden Agenten nie. Hinzu
kommt: Mehrere gleichnamige Dateien erzeugen keinen Widerspruch und keine
Warnung. Sie liegen einfach nebeneinander und die Aufloesung entscheidet
stillschweigend. Das System arbeitet korrekt im Sinne der jeweils gelesenen
Datei, wie der Commit bei marek.o zeigt: Der Agent haelt sich an die Datei, die
er tatsaechlich liest. Nur ist eben nicht erkennbar, welche das ist. Der
Mechanismus ist ein Auffindbarkeits- und Verstaendnisproblem, kein
Funktionsdefekt.

---

## Folie 4 — Die Suchreihenfolge ist nirgends dokumentiert

Es gibt eine Aufloesung, aber keine Dokumentation darueber. Die Quellen belegen,
dass mehrere Kandidaten existieren: Home, Projektpfad, WSL und unter Windows
Roaming. Sie belegen jedoch nicht, in welcher Reihenfolge geprueft wird und
welche Ebene Vorrang hat. Ob der Projektpfad das Home-Verzeichnis ueberschreibt
oder umgekehrt, ist aus dem Korpus nicht beantwortbar. Diese Luecke ist Teil
des Problems: Ohne belegte Vorrangsordnung kann sich niemand die wirksame Datei
herleiten. Die Nutzer helfen sich deshalb mit Arbeitsschritten, die das System
nicht anbietet: marek.o liest die Kandidaten per `find` aus und prueft sie von
Hand. Die Kern-Luecke der Recherche ist genau diese nicht belegte
Prioritaetsordnung. Sie ist nicht erfunden worden, sondern sie fehlt schlicht
in den vorliegenden Quellen und muesste gegen die echte Erweiterung verifiziert
werden.

---

## Folie 5 — Die Loesung existiert bereits

Fuer die Diagnose existiert bereits ein Werkzeug, es ist nur nicht auffindbar.
Die Kommandozeile bietet dafuer vier Befehle. `hermes config path` druckt den
effektiv geladenen Pfad. `hermes config show` zeigt die aufgeloeste
Konfiguration samt der beteiligten Pfade. `hermes config get <key>` gibt den
aufgeloesten effektiven Wert eines Eintrags zurueck. `hermes config check`
meldet fehlende oder veraltete Optionen. Diese Befehle wurden per CLI geprueft
und existieren. Sie ersetzen das Suchen mit `find` und das Handlesen der Datei:
Statt Kandidaten zu erraten, zeigt das Werkzeug an, welche Datei tatsaechlich
wirkt und welche Werte daraus resultieren. Der Hebel des Videos ist damit,
diese vorhandene Loesung zugaenglich zu machen. Es geht nicht darum, etwas
Neues zu bauen, sondern eine bestehende Faehigkeit bekannt zu machen.

---

## Folie 6 — Was noch fehlt: zwei Anforderungen

Die vorhandenen Befehle loesen die Diagnose, aber nicht alles. Zwei Punkte
bleiben offen. Erstens gibt es heute keine Warnung, wenn mehrere gleichnamige
config.toml-Dateien existieren und miteinander konkurrieren. Eine solche
Meldung muesste erst gebaut werden; sie ist in den Quellen als fehlend
beschrieben, existiert aber nicht. Zweitens ist die Prioritaets- und
Suchreihenfolge der Pfade nirgends dokumentiert. Diese Reihenfolge muesste
festgehalten werden, damit sich Nutzer die wirksame Datei herleiten koennen.
Dazu kommt eine Designvorgabe: In denselben Konfigurationsdateien liegen nach
Angabe von tessa_k API-Keys. Jede Anzeige der Konfiguration muss diese Secrets
redigieren, damit sie nicht ungefiltert ausgegeben werden. Diese Vorgabe gilt
fuer jede zukuenftige Anzeige-Loesung und ist mitzufuehren. Das Video selbst
baut keine dieser Anforderungen, es benennt sie als offene Punkte.

---

## Folie 7 — Grenzen: Was diese Hebel nicht loesen

Die vorgestellten Hebel haben klare Grenzen. Erstens ist die Prioritaetsordnung
der Pfade weiterhin offen. Sie ist gegen die echte Erweiterung zu verifizieren
und darf nicht erfunden werden. Zweitens muss die Warnung bei konkurrierenden
gleichnamigen Dateien erst gebaut werden; das Video baut nichts und loest diese
Anforderung nicht. Drittens sind die Schadensfaelle in den Quellen
Selbstauskunft ohne Artefakte. Ein Commit in einem Kundenrepo oder zwei
verlorene Arbeitstage sind nicht extern nachpruefbar; sie stuetzen sich auf
die Aussagen der Nutzer. Die Redaktion von Secrets betrifft ausserdem jede
Anzeige, nicht nur die Diagnose-Befehle. Zusammengefasst: Das Video macht eine
vorhandene Diagnose zugaenglich, es beseitigt keine der offenen
Sicherheitsluecken und es ersetzt keine belegte oder unbelegte Prioritaets-
angabe durch eine eigene. Die Grenzen bleiben bestehen.
