import { describe, expect, it } from "vitest";
import {
  isOAuthCallbackPath,
  isPasswordlessBypassPath,
} from "../../../apps/api/src/utils/two-factor-session-guard";

/**
 * Unit tests for the passwordless bypass-path classifier.
 *
 * The better-auth two-factor plugin only challenges the password sign-in paths
 * (`/sign-in/email`, `/sign-in/username`, `/sign-in/phone-number`). These
 * helpers recognise the three session-building paths the plugin does NOT
 * intercept, so the `session.create.before` guard can refuse them for users
 * with 2FA enabled. See S2-F2 4b/4.
 */
describe("isOAuthCallbackPath", () => {
  it.each([
    "/callback/google",
    "/callback/github",
    "/callback/custom",
    "/oauth2/callback/xyz",
  ])("classifies %s as an OAuth callback", (path) => {
    expect(isOAuthCallbackPath(path)).toBe(true);
  });

  it.each([
    "/sign-in/email",
    "/magic-link/verify",
    "/sign-in/email-otp",
    "/get-session",
  ])("does not classify %s as an OAuth callback", (path) => {
    expect(isOAuthCallbackPath(path)).toBe(false);
  });
});

describe("isPasswordlessBypassPath", () => {
  it.each([
    "/magic-link/verify",
    "/sign-in/email-otp",
    "/email-otp/verify-email",
    "/callback/google",
    "/oauth2/callback/xyz",
  ])("marks %s as a path the two-factor plugin does not intercept", (path) => {
    expect(isPasswordlessBypassPath(path)).toBe(true);
  });

  // The password sign-in is exactly the path the plugin DOES intercept and
  // turn into the 2FA challenge, so it must not be blocked here.
  it.each([
    "/sign-in/email",
    "/sign-in/username",
    "/sign-in/phone-number",
    "/get-session",
  ])("does not mark the password sign-in %s as a bypass", (path) => {
    expect(isPasswordlessBypassPath(path)).toBe(false);
  });
});
