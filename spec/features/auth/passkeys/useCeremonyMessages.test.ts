// The error/status pair every passkey ceremony reads and writes through this hook, replacing the
// Stimulus `error`/`status` targets.
import { act, renderHook } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { useCeremonyMessages } from "@/features/auth/passkeys/useCeremonyMessages";

describe("useCeremonyMessages", () => {
  it("starts with no error and no status", () => {
    const { result } = renderHook(() => useCeremonyMessages());

    expect(result.current.error).toBe("");
    expect(result.current.status).toBe("");
  });

  it("shows a status message", () => {
    const { result } = renderHook(() => useCeremonyMessages());

    act(() => {
      result.current.showStatus("認証オプションを取得中...");
    });

    expect(result.current.status).toBe("認証オプションを取得中...");
    expect(result.current.error).toBe("");
  });

  it("clears the status when an error is shown, exactly as the Stimulus target did", () => {
    const { result } = renderHook(() => useCeremonyMessages());

    act(() => {
      result.current.showStatus("認証オプションを取得中...");
    });
    act(() => {
      result.current.showError("失敗しました");
    });

    expect(result.current.error).toBe("失敗しました");
    expect(result.current.status).toBe("");
  });

  it("clears both messages", () => {
    const { result } = renderHook(() => useCeremonyMessages());

    act(() => {
      result.current.showError("失敗しました");
    });
    act(() => {
      result.current.clearMessages();
    });

    expect(result.current.error).toBe("");
    expect(result.current.status).toBe("");
  });
});
