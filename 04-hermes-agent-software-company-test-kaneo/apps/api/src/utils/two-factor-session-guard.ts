/**
 * Helfer, um die passwortlosen Anmeldewege zu erkennen, die eine Session bauen,
 * ohne dass der 2FA-Challenge-Hook des better-auth `two-factor`-Plugins greift.
 *
 * Der Plugin-Hook (der einzige Ort, der bei `user.twoFactorEnabled` die Session
 * zur Herausforderung verwirft) matcht nur die Passwort-Pfade (`/sign-in/email`,
 * `/sign-in/username`, `/sign-in/phone-number`). Magic-Link, E-Mail-OTP und
 * OAuth-Callback bauen dagegen eine Session direkt. Diese Pfade müssen für
 * Nutzer mit aktiviertem 2FA eine Session-Erzeugung verweigern, sonst wäre der
 * zweite Faktor eine Hintertür. Siehe S2-F2 4b/4.
 */

/** Best-effort Erkennung von OAuth/OIDC-Callback-Pfaden, die zu einer Session führen. */
export function isOAuthCallbackPath(path: unknown): boolean {
  if (typeof path !== "string") return false;
  return path.startsWith("/callback/") || path.startsWith("/oauth2/callback/");
}

/**
 * True, wenn der Pfad eine Session über einen Anmeldeweg baut, den das
 * two-factor-Plugin NICHT abfängt. Genau diese Pfade dürfen bei aktiviertem 2FA
 * keine Session erzeugen.
 */
export function isPasswordlessBypassPath(path: unknown): boolean {
  if (typeof path !== "string") return false;
  return (
    path === "/magic-link/verify" ||
    path === "/sign-in/email-otp" ||
    path === "/email-otp/verify-email" ||
    isOAuthCallbackPath(path)
  );
}
