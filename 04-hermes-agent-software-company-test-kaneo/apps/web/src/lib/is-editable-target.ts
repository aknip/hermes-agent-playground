/**
 * True, wenn das Ereignisziel ein bearbeitbares Textelement ist. Einzige
 * Quelle der Wahrheit für die Textfeld-Prüfung der Tastatur-Zuhörer — keine
 * zweite, ähnliche Prüfung an anderer Stelle (siehe Befund Palette-Keydown).
 */
export function isEditableTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  return (
    target.tagName === "INPUT" ||
    target.tagName === "TEXTAREA" ||
    target.contentEditable === "true"
  );
}
