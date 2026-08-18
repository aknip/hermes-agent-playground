/**
 * Erkennung der 2FA-Abweisung auf den passwortlosen Anmeldewegen.
 *
 * Der better-auth-Web-Client hängt bei der 401-Antwort des email-otp-Sign-ins
 * für Konten mit aktiviertem 2FA — das Promise bleibt aus und die verify-otp-
 * Seite bliebe endlos auf „Verifying...“. Deshalb führt die Seite den Aufruf
 * selbst per `fetch` aus und muss die 2FA-Abweisung von einem schlicht falschen
 * Code unterscheiden können.
 *
 * Vertrag mit dem Server (auth.ts, `session.create.before`-Hook): Die
 * 2FA-Abweisung ist eine 401 mit der Meldung „…Zwei-Faktor…“. Ein falscher
 * Code kommt als 400 mit `code: "INVALID_OTP"` zurück. An diesem stabilen
 * Meldungsteil erkennen wir den Fall, damit die Abweisung verständlich und
 * handlungsleitend angezeigt werden kann.
 */

/** Wahr, wenn die Antwortmeldung die 2FA-Abweisung des Server-Hooks ist. */
export function isTwoFactorRequiredMessage(message: unknown): boolean {
  return typeof message === "string" && message.includes("Zwei-Faktor");
}

/** Basis-URL der API, vor die der Auth-Pfad gehängt wird. */
export function getAuthApiBaseUrl(): string {
  const apiUrl = import.meta.env.VITE_API_URL || "http://localhost:1337";
  try {
    const url = new URL(apiUrl);
    return `${url.protocol}//${url.host}`;
  } catch {
    return apiUrl.split("/").slice(0, 3).join("/");
  }
}
