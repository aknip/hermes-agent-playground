import { createHmac } from "node:crypto";
import { decodeBase32IgnorePadding } from "@oslojs/encoding";

// RFC 6238 TOTP generator used by the 2FA E2E journey. The two-factor plugin
// (better-auth) verifies codes produced by `createOTP` from `@better-auth/utils`:
// SHA-1, 6 digits, 30s period, secret as base32 (see specs/r1-f2-zwei-faktor.html).
// This helper reproduces exactly that format so the E2E test can compute the
// current code without a real authenticator. Kept deliberately dependency-free
// (Node crypto + the base32 decoder already present in the api package).
export interface GenerateTotpOptions {
  /** Digits in the emitted code. RFC 6238 default 6; matches better-auth. */
  digits?: number;
  /** Period in seconds. RFC 6238 default 30; matches better-auth. */
  period?: number;
  /**
   * Unix timestamp (ms) to compute the code for. Defaults to now. Tests pass
   * a fixed time to make the code deterministic.
   */
  timestampMs?: number;
}

export function generateTotp(
  secretBase32: string,
  options: GenerateTotpOptions = {},
): string {
  const digits = options.digits ?? 6;
  const period = options.period ?? 30;
  const timestampMs = options.timestampMs ?? Date.now();

  const secret = decodeBase32IgnorePadding(secretBase32);
  const counter = Math.floor(timestampMs / 1000 / period);

  // HOTP (RFC 4226): HMAC-SHA1 over the 8-byte big-endian counter, dynamic
  // truncation to 4 bytes, then mod 10^digits, zero-padded.
  const counterBuffer = Buffer.alloc(8);
  counterBuffer.writeBigUInt64BE(BigInt(counter), 0);
  const hmac = createHmac("sha1", secret).update(counterBuffer).digest();
  // SHA-1 digests are always 20 bytes, so the last byte and the four bytes at
  // the truncation offset are guaranteed present.
  const offset = (hmac[hmac.length - 1] ?? 0) & 0x0f;
  const o0 = hmac[offset] ?? 0;
  const o1 = hmac[offset + 1] ?? 0;
  const o2 = hmac[offset + 2] ?? 0;
  const o3 = hmac[offset + 3] ?? 0;
  const binary =
    ((o0 & 0x7f) << 24) |
    ((o1 & 0xff) << 16) |
    ((o2 & 0xff) << 8) |
    (o3 & 0xff);
  const otp = (binary % 10 ** digits).toString().padStart(digits, "0");
  return otp;
}
