// The one button.
//
// Wraps React Aria's `Button`, which owns the press, hover and focus behaviour that used to be
// hand-written: it normalises pointer, touch and keyboard activation, and exposes each state as a
// data attribute that the `tailwindcss-react-aria-components` plugin turns into a variant
// (`pressed:`, `hovered:`, `disabled:`). Nothing here re-implements any of that.
//
// The focus ring is not declared here on purpose. `src/styles/theme.css` paints one
// `:focus-visible` outline for the whole document, so every focusable element agrees without each
// component restating it.
import { Button as AriaButton, type ButtonProps as AriaButtonProps } from "react-aria-components";

export type ButtonVariant = "primary" | "secondary" | "danger" | "ghost";
export type ButtonSize = "sm" | "md";

export type ButtonProps = AriaButtonProps & {
  variant?: ButtonVariant;
  size?: ButtonSize;
};

const BASE =
  "inline-flex items-center justify-center gap-2 rounded-md font-medium transition-colors " +
  "pressed:opacity-90 disabled:cursor-not-allowed disabled:opacity-50";

const VARIANTS: Record<ButtonVariant, string> = {
  primary: "bg-accent text-accent-fg hovered:bg-accent-hover",
  secondary: "border border-line bg-surface text-fg hovered:bg-surface-muted",
  danger: "bg-danger text-danger-fg hovered:bg-danger-hover",
  ghost: "text-fg hovered:bg-surface-muted",
};

const SIZES: Record<ButtonSize, string> = {
  sm: "px-3 py-1.5 text-sm",
  md: "px-4 py-2 text-sm",
};

export default function Button({
  variant = "primary",
  size = "md",
  className,
  ...props
}: ButtonProps) {
  // React Aria accepts a function for `className` so a caller can react to state. Resolving it here
  // keeps that contract working instead of silently dropping the caller's function.
  return (
    <AriaButton
      {...props}
      className={(renderProps) =>
        [
          BASE,
          VARIANTS[variant],
          SIZES[size],
          typeof className === "function" ? className(renderProps) : className,
        ]
          .filter(Boolean)
          .join(" ")
      }
    />
  );
}
