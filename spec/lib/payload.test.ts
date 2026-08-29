// Reading a parsed JSON response without claiming to know its shape. Every reader answers
// `undefined` (or, for `readRecord`, an empty record) when the property is missing, or is of
// another type, rather than asserting a type the server made no promise to keep.
import { describe, expect, it } from "vitest";

import { readBoolean, readNumber, readObject, readRecord, readString } from "@/lib/payload";

describe("readString", () => {
  it("answers a string-valued property", () => {
    expect(readString({ name: "someone" }, "name")).toBe("someone");
  });

  it("answers undefined for a missing property", () => {
    expect(readString({}, "name")).toBeUndefined();
  });

  it("answers undefined for a property of another type", () => {
    expect(readString({ name: 42 }, "name")).toBeUndefined();
  });

  it("answers undefined for a non-object payload", () => {
    expect(readString(null, "name")).toBeUndefined();
    expect(readString(undefined, "name")).toBeUndefined();
    expect(readString("a string", "name")).toBeUndefined();
    expect(readString(42, "name")).toBeUndefined();
  });
});

describe("readNumber", () => {
  it("answers a number-valued property", () => {
    expect(readNumber({ retry_after: 30 }, "retry_after")).toBe(30);
  });

  it("answers undefined for a missing property", () => {
    expect(readNumber({}, "retry_after")).toBeUndefined();
  });

  it("answers undefined for a property of another type", () => {
    expect(readNumber({ retry_after: "30" }, "retry_after")).toBeUndefined();
  });

  it("answers undefined for a non-object payload", () => {
    expect(readNumber(null, "retry_after")).toBeUndefined();
  });
});

describe("readBoolean", () => {
  it("answers a boolean-valued property", () => {
    expect(readBoolean({ resendable: true }, "resendable")).toBe(true);
    expect(readBoolean({ resendable: false }, "resendable")).toBe(false);
  });

  it("answers undefined for a missing property", () => {
    expect(readBoolean({}, "resendable")).toBeUndefined();
  });

  it("answers undefined for a property of another type", () => {
    expect(readBoolean({ resendable: "true" }, "resendable")).toBeUndefined();
  });

  it("answers undefined for a non-object payload", () => {
    expect(readBoolean(null, "resendable")).toBeUndefined();
  });
});

describe("readObject", () => {
  it("answers an object-valued property", () => {
    const options = { challenge: "abc" };
    expect(readObject({ options }, "options")).toBe(options);
  });

  it("answers undefined for a missing property", () => {
    expect(readObject({}, "options")).toBeUndefined();
  });

  it("answers undefined for a property of another type", () => {
    expect(readObject({ options: "not-an-object" }, "options")).toBeUndefined();
  });

  it("answers undefined for a null-valued property", () => {
    expect(readObject({ options: null }, "options")).toBeUndefined();
  });

  it("answers undefined for a non-object payload", () => {
    expect(readObject(null, "options")).toBeUndefined();
  });
});

describe("readRecord", () => {
  it("keeps only the string-valued properties", () => {
    expect(readRecord({ address: "someone@example.test", verified: true, age: 3 })).toEqual({
      address: "someone@example.test",
    });
  });

  it("answers an empty record for a non-object payload", () => {
    expect(readRecord(null)).toEqual({});
    expect(readRecord(undefined)).toEqual({});
    expect(readRecord("a string")).toEqual({});
  });

  it("answers an empty record for a payload with no string-valued properties", () => {
    expect(readRecord({ verified: true })).toEqual({});
  });
});
