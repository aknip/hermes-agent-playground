// Holt den Monatsbericht und stellt ihn dar.
// Die Daten kommen im Ausbauzustand aus einer statischen Datei; die
// Anbindung an ein Backend ist noch nicht gebaut.

const TARGET = document.getElementById('report');

async function loadMonthlyTotals() {
  try {
    const response = await fetch('monthly-totals.txt');
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    TARGET.textContent = await response.text();
  } catch (error) {
    TARGET.textContent = `Bericht nicht verfuegbar: ${error.message}`;
  }
}

loadMonthlyTotals();
