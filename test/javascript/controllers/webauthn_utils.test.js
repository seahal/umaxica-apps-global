import { describe, expect, test } from "vite-plus/test";

import {
  normalizePublicKeyOptions,
  toArrayBuffer,
} from "../../../app/javascript/controllers/webauthn_utils.js";

// Mock atob if not available (Node.js environment)
if (typeof atob === "undefined") {
  global.atob = (str) => Buffer.from(str, "base64").toString("binary");
}

describe("webauthn_utils", () => {
  describe("toArrayBuffer", () => {
    test("Base64URL 文字列を ArrayBuffer に変換する", () => {
      const input = "SGVsbG8td29ybGQ_"; // Hello-world? (Base64URL)
      const buffer = toArrayBuffer(input);
      expect(buffer).toBeInstanceOf(ArrayBuffer);
      const bytes = new Uint8Array(buffer);
      expect(bytes[0]).toBe(72); // 'H'
    });

    test("ArrayBuffer をそのまま返す", () => {
      const buffer = new ArrayBuffer(8);
      expect(toArrayBuffer(buffer)).toBe(buffer);
    });

    test("バイト配列を ArrayBuffer に変換する", () => {
      const input = [72, 101, 108, 108, 111];
      const buffer = toArrayBuffer(input);
      expect(new Uint8Array(buffer)[0]).toBe(72);
    });

    test("null のとき TypeError を投げる", () => {
      expect(() => toArrayBuffer(null)).toThrow(TypeError);
      expect(() => toArrayBuffer(null)).toThrow("null");
    });

    test("undefined のとき TypeError を投げる", () => {
      expect(() => toArrayBuffer(undefined)).toThrow(TypeError);
      expect(() => toArrayBuffer(undefined)).toThrow("undefined");
    });

    test("number のとき TypeError を投げる", () => {
      expect(() => toArrayBuffer(123)).toThrow(TypeError);
      expect(() => toArrayBuffer(123)).toThrow("number");
    });

    test("constructor のないオブジェクトで typeof fallback を確認する", () => {
      const obj = Object.create(null);
      expect(() => toArrayBuffer(obj)).toThrow("object");
    });
  });

  describe("normalizePublicKeyOptions", () => {
    test("challenge と user.id を Base64URL から ArrayBuffer に変換する", () => {
      const options = { challenge: "Y2hhbGxlbmdl", user: { id: "dXNlcmlk" } };
      const normalized = normalizePublicKeyOptions(options);
      expect(normalized.challenge).toBeInstanceOf(ArrayBuffer);
      expect(normalized.user.id).toBeInstanceOf(ArrayBuffer);
    });

    test("publicKey プロパティがある場合、その中身を正規化する", () => {
      const options = { publicKey: { challenge: "Y2hhbGxlbmdl" } };
      const normalized = normalizePublicKeyOptions(options);
      expect(normalized.challenge).toBeInstanceOf(ArrayBuffer);
    });

    test("excludeCredentials の id を正規化する", () => {
      const options = { excludeCredentials: [{ id: "Y3JlZGlk" }] };
      const normalized = normalizePublicKeyOptions(options);
      expect(normalized.excludeCredentials[0].id).toBeInstanceOf(ArrayBuffer);
    });

    test("allowCredentials の id を正規化する", () => {
      const options = { allowCredentials: [{ id: "YWxsb3dpZA" }] };
      const normalized = normalizePublicKeyOptions(options);
      expect(normalized.allowCredentials[0].id).toBeInstanceOf(ArrayBuffer);
    });

    test("null や undefined の options に TypeError を投げる", () => {
      expect(() => normalizePublicKeyOptions(null)).toThrow(TypeError);
      expect(() => normalizePublicKeyOptions(undefined)).toThrow(TypeError);
      expect(() => normalizePublicKeyOptions("string")).toThrow(TypeError);
    });

    test("excludeCredentials が undefined のときそのままにする", () => {
      const options = { challenge: "Y2hhbGxlbmdl" };
      const normalized = normalizePublicKeyOptions(options);
      expect(normalized.excludeCredentials).toBeUndefined();
    });

    test("excludeCredentials が null のときそのままにする", () => {
      const options = { excludeCredentials: null };
      const normalized = normalizePublicKeyOptions(options);
      expect(normalized.excludeCredentials).toBeNull();
    });

    test("excludeCredentials が配列でないとき TypeError を投げる", () => {
      const options = { excludeCredentials: "not-array" };
      expect(() => normalizePublicKeyOptions(options)).toThrow(TypeError);
    });

    test("allowCredentials が配列でないとき TypeError を投げる", () => {
      const options = { allowCredentials: "not-array" };
      expect(() => normalizePublicKeyOptions(options)).toThrow(TypeError);
    });
  });
});
