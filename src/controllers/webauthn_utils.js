function describeInput(input) {
  if (input === null) {
    return "null";
  }
  if (input === undefined) {
    return "undefined";
  }
  if (input && input.constructor && input.constructor.name) {
    return `${typeof input}(${input.constructor.name})`;
  }
  return typeof input;
}

export function toArrayBuffer(input, label = "value") {
  if (typeof input === "string") {
    const base64 = input.replace(/-/g, "+").replace(/_/g, "/");
    const padding = "=".repeat((4 - (base64.length % 4)) % 4);
    const binary = atob(base64 + padding);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
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

function normalizeCredentialList(list, label) {
  if (list === undefined || list === null) {
    return list;
  }
  if (!Array.isArray(list)) {
    throw new TypeError(`${label} must be an array`);
  }
  return list.map((cred, index) => ({
    ...cred,
    id: toArrayBuffer(cred?.id, `${label}[${index}].id`),
  }));
}

export function normalizePublicKeyOptions(options) {
  if (!options || typeof options !== "object") {
    throw new TypeError(`Expected options to be an object, got ${describeInput(options)}`);
  }

  const source = options.publicKey ? options.publicKey : options;
  const normalized = { ...source };

  if ("challenge" in source) {
    normalized.challenge = toArrayBuffer(source.challenge, "challenge");
  }

  if (source.user && "id" in source.user) {
    normalized.user = { ...source.user, id: toArrayBuffer(source.user.id, "user.id") };
  }

  if ("excludeCredentials" in source) {
    normalized.excludeCredentials = normalizeCredentialList(
      source.excludeCredentials,
      "excludeCredentials",
    );
  }

  if ("allowCredentials" in source) {
    normalized.allowCredentials = normalizeCredentialList(
      source.allowCredentials,
      "allowCredentials",
    );
  }

  return normalized;
}
