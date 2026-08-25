// Converting the WebAuthn options Rails serialises into the ArrayBuffer-valued shape the browser
// credential API requires.
//
// The server sends challenge and credential ids as base64url strings because JSON has no binary
// type. Everything here is about that boundary, so the input is `unknown` and each field is
// checked rather than assumed: a payload that does not carry what it should fails here, naming the
// field, instead of reaching `navigator.credentials` as the wrong type.
function describeInput(input: unknown): string {
  if (input === null) {
    return "null";
  }
  if (input === undefined) {
    return "undefined";
  }
  const name: unknown = Reflect.get(Object.getPrototypeOf(Object(input)) ?? {}, "constructor");
  const constructorName: unknown =
    typeof name === "function" ? Reflect.get(name, "name") : undefined;
  if (typeof constructorName === "string" && constructorName !== "") {
    return `${typeof input}(${constructorName})`;
  }
  return typeof input;
}

export function toArrayBuffer(input: unknown, label = "value"): ArrayBuffer {
  if (typeof input === "string") {
    const base64 = input.replaceAll("-", "+").replaceAll("_", "/");
    const padding = "=".repeat((4 - (base64.length % 4)) % 4);
    const binary = atob(base64 + padding);
    const bytes = new Uint8Array(binary.length);
    // `charCodeAt`, not `codePointAt`: `atob` answers a binary string whose units are bytes, and
    // `codePointAt` would combine a surrogate pair into one value and lose a byte.
    for (let i = 0; i < binary.length; i++) {
      // oxlint-disable-next-line unicorn/prefer-code-point
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
  }

  if (input instanceof ArrayBuffer) {
    return input;
  }

  if (Array.isArray(input)) {
    return Uint8Array.from(input).buffer;
  }

  throw new TypeError(
    `Expected ${label} to be a base64url string, ArrayBuffer, or byte array, got ${describeInput(input)}`,
  );
}

type CredentialDescriptor = Record<string, unknown> & { id: ArrayBuffer };

function normalizeCredentialList(
  list: unknown,
  label: string,
): CredentialDescriptor[] | null | undefined {
  if (list === undefined || list === null) {
    return list;
  }
  if (!isUnknownArray(list)) {
    throw new TypeError(`${label} must be an array`);
  }
  return list.map((cred, index) => ({
    ...asRecord(cred),
    id: toArrayBuffer(asRecord(cred)["id"], `${label}[${index}].id`),
  }));
}

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null ? { ...value } : {};
}

export function normalizePublicKeyOptions(options: unknown): Record<string, unknown> {
  if (typeof options !== "object" || options === null) {
    throw new TypeError(`Expected options to be an object, got ${describeInput(options)}`);
  }

  const outer = asRecord(options);
  const source = asRecord(outer["publicKey"] ?? outer);
  const normalized: Record<string, unknown> = { ...source };

  if ("challenge" in source) {
    normalized["challenge"] = toArrayBuffer(source["challenge"], "challenge");
  }

  const { user } = source;
  if (typeof user === "object" && user !== null && "id" in user) {
    const userRecord = asRecord(user);
    normalized["user"] = { ...userRecord, id: toArrayBuffer(userRecord["id"], "user.id") };
  }

  if ("excludeCredentials" in source) {
    normalized["excludeCredentials"] = normalizeCredentialList(
      source["excludeCredentials"],
      "excludeCredentials",
    );
  }

  if ("allowCredentials" in source) {
    normalized["allowCredentials"] = normalizeCredentialList(
      source["allowCredentials"],
      "allowCredentials",
    );
  }

  return normalized;
}

function requireString(value: unknown, label: string): string {
  if (typeof value !== "string") {
    throw new TypeError(`Expected ${label} to be a string, got ${describeInput(value)}`);
  }
  return value;
}

function optionalString(value: unknown, label: string): string | undefined {
  return value === undefined || value === null ? undefined : requireString(value, label);
}

// `Array.isArray` narrows an `unknown` to `any[]`, which drops the checking on every element it
// then feeds. This predicate proves the same thing and keeps the elements `unknown`.
function isUnknownArray(value: unknown): value is unknown[] {
  return Array.isArray(value);
}

function requireNumber(value: unknown, label: string): number {
  if (typeof value !== "number") {
    throw new TypeError(`Expected ${label} to be a number, got ${describeInput(value)}`);
  }
  return value;
}

function requireBuffer(value: unknown, label: string): ArrayBuffer {
  if (!(value instanceof ArrayBuffer)) {
    throw new TypeError(`Expected ${label} to have been normalized to an ArrayBuffer`);
  }
  return value;
}

/**
 * The options for `navigator.credentials.get`, with the fields WebAuthn requires checked.
 *
 * The server builds this payload, so a missing `challenge` is a server bug; naming it here beats
 * the browser's own "an invalid state" error, which says nothing about which field was wrong.
 */
export function normalizeRequestOptions(options: unknown): PublicKeyCredentialRequestOptions {
  const normalized = normalizePublicKeyOptions(options);

  return {
    ...normalized,
    challenge: requireBuffer(normalized["challenge"], "challenge"),
  };
}

/** The options for `navigator.credentials.create`, with the fields WebAuthn requires checked. */
export function normalizeCreationOptions(options: unknown): PublicKeyCredentialCreationOptions {
  const normalized = normalizePublicKeyOptions(options);
  const { rp, user, pubKeyCredParams } = normalized;

  if (typeof rp !== "object" || rp === null) {
    throw new TypeError("Expected the credential creation options to carry an `rp` object");
  }

  if (typeof user !== "object" || user === null) {
    throw new TypeError("Expected the credential creation options to carry a `user` object");
  }

  if (!isUnknownArray(pubKeyCredParams)) {
    throw new TypeError("Expected the credential creation options to carry `pubKeyCredParams`");
  }

  // Each entry is read back through the two fields WebAuthn requires, so the list is checked
  // rather than only its shape.
  const credentialParameters: PublicKeyCredentialParameters[] = pubKeyCredParams.map(
    (parameter, index) => ({
      type: "public-key",
      alg: requireNumber(Reflect.get(Object(parameter), "alg"), `pubKeyCredParams[${index}].alg`),
    }),
  );

  const rpId = optionalString(Reflect.get(rp, "id"), "rp.id");

  return {
    ...normalized,
    challenge: requireBuffer(normalized["challenge"], "challenge"),
    rp: {
      name: requireString(Reflect.get(rp, "name"), "rp.name"),
      ...(rpId === undefined ? {} : { id: rpId }),
    },
    user: {
      ...user,
      id: requireBuffer(Reflect.get(user, "id"), "user.id"),
      name: requireString(Reflect.get(user, "name"), "user.name"),
      displayName: requireString(Reflect.get(user, "displayName"), "user.displayName"),
    },
    pubKeyCredParams: credentialParameters,
  };
}
