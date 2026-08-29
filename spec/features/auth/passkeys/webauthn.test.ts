// Typed WebAuthn glue behind every React-ported passkey ceremony. Option normalisation is
// `@/controllers/webauthn_utils`'s own concern and is covered there; what belongs here is the
// encoding this module owns: base64url with no padding, and which credential shape each ceremony
// accepts.
import { afterEach, describe, expect, it, vi } from "vitest";

import {
  createCredential,
  getAssertion,
  passkeysSupported,
} from "@/features/auth/passkeys/webauthn";

import {
  CREATION_OPTIONS,
  REQUEST_OPTIONS,
  assertionCredential,
  attestationCredential,
  stubCredentialsApi,
} from "../../../support/webauthn";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("passkeysSupported", () => {
  it("is true when the platform exposes PublicKeyCredential", () => {
    stubCredentialsApi();

    expect(passkeysSupported()).toBe(true);
  });

  it("is false when the platform exposes no PublicKeyCredential", () => {
    vi.stubGlobal("PublicKeyCredential", undefined);

    expect(passkeysSupported()).toBe(false);
  });
});

describe("getAssertion", () => {
  it("serializes the assertion as unpadded base64url", async () => {
    const credentials = stubCredentialsApi();
    credentials.get.mockResolvedValue(assertionCredential());

    const serialized = await getAssertion(REQUEST_OPTIONS);

    expect(serialized).toEqual({
      id: "cred-id",
      rawId: "AQID",
      type: "public-key",
      authenticatorAttachment: null,
      response: {
        clientDataJSON: "BAUG",
        authenticatorData: "BwgJ",
        signature: "CgsM",
        userHandle: null,
      },
      clientExtensionResults: {},
    });
    // Base64url has no `+`, `/`, or `=` padding.
    expect(serialized.rawId).not.toMatch(/[+/=]/u);
  });

  it("carries the authenticator's userHandle when it answers one", async () => {
    const credentials = stubCredentialsApi();
    credentials.get.mockResolvedValue(
      assertionCredential({ userHandle: new Uint8Array([1, 2, 3]).buffer }),
    );

    const serialized = await getAssertion(REQUEST_OPTIONS);

    expect(serialized.response["userHandle"]).toBe("AQID");
  });

  it("carries the authenticatorAttachment the authenticator answers", async () => {
    const credentials = stubCredentialsApi();
    credentials.get.mockResolvedValue(assertionCredential({ authenticatorAttachment: "platform" }));

    const serialized = await getAssertion(REQUEST_OPTIONS);

    expect(serialized.authenticatorAttachment).toBe("platform");
  });

  it("rejects when the authenticator returns no credential", async () => {
    const credentials = stubCredentialsApi();
    credentials.get.mockResolvedValue(null);

    await expect(getAssertion(REQUEST_OPTIONS)).rejects.toThrow(
      "No credential was returned by the authenticator",
    );
  });

  it("rejects when the credential is not a WebAuthn assertion", async () => {
    const credentials = stubCredentialsApi();
    credentials.get.mockResolvedValue({ id: "cred-id", type: "public-key" });

    await expect(getAssertion(REQUEST_OPTIONS)).rejects.toThrow(
      "The authenticator returned a credential that is not a WebAuthn assertion",
    );
  });

  it("rejects when the credential carries a response that is not an object", async () => {
    const credentials = stubCredentialsApi();
    const credentialWithNonObjectResponse = {
      id: "cred-id",
      type: "public-key",
      rawId: "x",
      response: null,
    };
    credentials.get.mockResolvedValue(credentialWithNonObjectResponse);

    await expect(getAssertion(REQUEST_OPTIONS)).rejects.toThrow(
      "The authenticator returned a credential that is not a WebAuthn assertion",
    );
  });
});

describe("createCredential", () => {
  it("serializes the attestation as unpadded base64url", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue(attestationCredential());

    const serialized = await createCredential(CREATION_OPTIONS);

    expect(serialized).toEqual({
      id: "cred-id",
      rawId: "AQID",
      type: "public-key",
      authenticatorAttachment: null,
      response: {
        clientDataJSON: "BAUG",
        attestationObject: "DQ4P",
        transports: ["internal"],
      },
      clientExtensionResults: {},
    });
  });

  it("reports no transports when the authenticator does not support the query", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue(attestationCredential({ transports: null }));

    const serialized = await createCredential(CREATION_OPTIONS);

    expect(serialized.response["transports"]).toEqual([]);
  });

  it("rejects when the authenticator returns no credential", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue(null);

    await expect(createCredential(CREATION_OPTIONS)).rejects.toThrow(
      "No credential was returned by the authenticator",
    );
  });

  it("rejects when the credential is not a WebAuthn attestation", async () => {
    const credentials = stubCredentialsApi();
    credentials.create.mockResolvedValue({ id: "cred-id", type: "public-key" });

    await expect(createCredential(CREATION_OPTIONS)).rejects.toThrow(
      "The authenticator returned a credential that is not a WebAuthn attestation",
    );
  });
});
