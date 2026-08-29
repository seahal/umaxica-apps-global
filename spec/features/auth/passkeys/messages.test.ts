// The error-mapping helpers behind every passkey ceremony's catch block. Each mirrors the
// `error.name` branches the Stimulus controllers used, so the message a visitor reads on a
// cancelled or blocked ceremony does not change with the port.
import { describe, expect, it } from "vitest";

import {
  PASSKEY_MESSAGES,
  authenticationErrorMessage,
  registrationErrorMessage,
} from "@/features/auth/passkeys/messages";

function domException(name: string): DOMException {
  return new DOMException("boom", name);
}

describe("authenticationErrorMessage", () => {
  it("maps a cancelled ceremony to its own copy", () => {
    expect(authenticationErrorMessage(domException("NotAllowedError"))).toBe(
      PASSKEY_MESSAGES.cancelled,
    );
  });

  it("maps a security error to its own copy", () => {
    expect(authenticationErrorMessage(domException("SecurityError"))).toBe(
      PASSKEY_MESSAGES.securityError,
    );
  });

  it("uses the error's own message for any other named error", () => {
    expect(authenticationErrorMessage(new Error("network down"))).toBe("network down");
  });

  it("falls back to its own copy when an Error carries no message", () => {
    expect(authenticationErrorMessage(new Error(""))).toBe(PASSKEY_MESSAGES.authenticationError);
  });

  it("falls back to its own copy when the failure is not an Error at all", () => {
    expect(authenticationErrorMessage("nope")).toBe(PASSKEY_MESSAGES.authenticationError);
  });
});

describe("registrationErrorMessage", () => {
  it("maps a cancelled ceremony to its own copy", () => {
    expect(registrationErrorMessage(domException("NotAllowedError"))).toBe(
      PASSKEY_MESSAGES.cancelled,
    );
  });

  it("maps a duplicate registration to its own copy", () => {
    expect(registrationErrorMessage(domException("InvalidStateError"))).toBe(
      PASSKEY_MESSAGES.alreadyRegistered,
    );
  });

  it("uses the error's own message for any other named error", () => {
    expect(registrationErrorMessage(new Error("network down"))).toBe("network down");
  });

  it("falls back to its own copy when an Error carries no message", () => {
    expect(registrationErrorMessage(new Error(""))).toBe(PASSKEY_MESSAGES.registrationError);
  });

  it("falls back to its own copy when the failure is not an Error at all", () => {
    expect(registrationErrorMessage("nope")).toBe(PASSKEY_MESSAGES.registrationError);
  });
});
