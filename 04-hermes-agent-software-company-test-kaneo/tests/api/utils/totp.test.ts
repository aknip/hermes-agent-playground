import { describe, expect, it } from "vitest";
import { generateTotp } from "../../../apps/api/src/utils/totp";

// RFC 6238 Appendix B test vectors (SHA-1, 8 digits in the RFC). The 6-digit
// truncations below are the last 6 digits of the RFC's 8-digit values. The
// helper under test must produce codes that better-auth's `createOTP` (the
// implementation used by the two-factor plugin) accepts — same secret format
// (base32), same SHA-1, same 30s period.
describe("generateTotp", () => {
  // base32("12345678901234567890") — the RFC 6238 shared test secret.
  const RFC_SECRET = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";

  it("produces the RFC 6238 codes for the shared test secret", () => {
    // The RFC's T is an absolute Unix timestamp in seconds; the 30s period
    // means counter = floor(T / 30).
    const cases: Array<[number, string]> = [
      [59, "287082"],
      [1111111109, "081804"],
      [1111111111, "050471"],
      [1234567890, "005924"],
      [2000000000, "279037"],
      [20000000000, "353130"],
    ];

    for (const [seconds, expected] of cases) {
      expect(
        generateTotp(RFC_SECRET, { timestampMs: seconds * 1000 }),
        `T=${seconds}`,
      ).toBe(expected);
    }
  });

  it("defaults to a 6-digit, 30-second-period code", () => {
    const timestampMs = 59 * 30 * 1000;
    const code = generateTotp(RFC_SECRET, { timestampMs });
    expect(code).toMatch(/^\d{6}$/);
  });
});
