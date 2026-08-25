// Reading a parsed JSON response without claiming to know its shape.
//
// `response.json()` answers `any`: asserting a type onto it tells the compiler a lie the server is
// under no obligation to keep. These readers check what actually arrived and answer `undefined`
// when the property is missing or of another type, so a malformed response takes the same path as
// an absent one instead of failing somewhere later as a wrong type.

function propertyOf(payload: unknown, key: string): unknown {
  if (typeof payload !== "object" || payload === null) {
    return undefined;
  }

  const value: unknown = Reflect.get(payload, key);
  return value;
}

export function readString(payload: unknown, key: string): string | undefined {
  const value = propertyOf(payload, key);
  return typeof value === "string" ? value : undefined;
}

export function readNumber(payload: unknown, key: string): number | undefined {
  const value = propertyOf(payload, key);
  return typeof value === "number" ? value : undefined;
}

export function readBoolean(payload: unknown, key: string): boolean | undefined {
  const value = propertyOf(payload, key);
  return typeof value === "boolean" ? value : undefined;
}

/** An object-valued property, for payloads that nest one, as `undefined` when it is not one. */
export function readObject(payload: unknown, key: string): unknown {
  const value = propertyOf(payload, key);
  return typeof value === "object" && value !== null ? value : undefined;
}

/** The string-valued properties of a payload, for the nested scopes a form's data carries. */
export function readRecord(payload: unknown): Record<string, string> {
  const record: Record<string, string> = {};
  if (typeof payload !== "object" || payload === null) {
    return record;
  }

  for (const key of Object.keys(payload)) {
    const value = propertyOf(payload, key);
    if (typeof value === "string") {
      record[key] = value;
    }
  }

  return record;
}
