import type { ButtonHTMLAttributes, HTMLAttributes, ReactNode } from "react";
import { forwardRef, useState } from "react";

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  isDisabled?: boolean;
};

type TextFieldProps = HTMLAttributes<HTMLDivElement> & {
  children?: ReactNode;
  isDisabled?: boolean;
  validationState?: "valid" | "invalid";
};

function togglePressState(
  setPressed: (pressed: boolean) => void,
  setFocusVisible: (focusVisible: boolean) => void,
): {
  onBlur: ButtonHTMLAttributes<HTMLButtonElement>["onBlur"];
  onFocus: ButtonHTMLAttributes<HTMLButtonElement>["onFocus"];
  onKeyDown: ButtonHTMLAttributes<HTMLButtonElement>["onKeyDown"];
  onKeyUp: ButtonHTMLAttributes<HTMLButtonElement>["onKeyUp"];
  onPointerCancel: ButtonHTMLAttributes<HTMLButtonElement>["onPointerCancel"];
  onPointerDown: ButtonHTMLAttributes<HTMLButtonElement>["onPointerDown"];
  onPointerLeave: ButtonHTMLAttributes<HTMLButtonElement>["onPointerLeave"];
  onPointerUp: ButtonHTMLAttributes<HTMLButtonElement>["onPointerUp"];
} {
  return {
    onBlur: () => {
      setPressed(false);
      setFocusVisible(false);
    },
    onFocus: () => {
      setFocusVisible(true);
    },
    onKeyDown: (event) => {
      if (event.key === " " || event.key === "Enter") {
        event.preventDefault();
        setPressed(true);
      }
    },
    onKeyUp: (event) => {
      if (event.key === " " || event.key === "Enter") {
        setPressed(false);
      }
    },
    onPointerCancel: () => {
      setPressed(false);
    },
    onPointerDown: () => {
      setPressed(true);
    },
    onPointerLeave: () => {
      setPressed(false);
    },
    onPointerUp: () => {
      setPressed(false);
    },
  };
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { children, className, isDisabled = false, ...props },
  ref,
) {
  const [pressed, setPressed] = useState(false);
  const [focusVisible, setFocusVisible] = useState(false);
  const interactionProps = togglePressState(setPressed, setFocusVisible);

  return (
    <button
      {...props}
      {...interactionProps}
      ref={ref}
      className={className}
      aria-disabled={isDisabled || undefined}
      data-disabled={isDisabled || undefined}
      data-focus-visible={focusVisible || undefined}
      data-pressed={pressed || undefined}
      disabled={isDisabled}
      type={props.type ?? "button"}
    >
      {children}
    </button>
  );
});

export const TextField = forwardRef<HTMLDivElement, TextFieldProps>(function TextField(
  { children, className, isDisabled = false, validationState, ...props },
  ref,
) {
  const dataAttributes = {
    "data-disabled": isDisabled || undefined,
    "data-invalid": validationState === "invalid" || undefined,
  };

  return (
    <div
      {...props}
      {...dataAttributes}
      ref={ref}
      className={className}
    >
      {children}
    </div>
  );
});
