// The one button appearance, shared by the two things that wear it.
//
// `Button` is a React Aria button and reports its states as data attributes, so it styles hover
// through the plugin's `hovered:` variant. `ButtonLink` is an anchor — a destination, not an
// action — and has no such attribute, so it styles hover through CSS `hover:`. Everything else
// about the two is the same, and keeping the palette and the metrics here is what stops a link
// that "looks like a button" from slowly ceasing to.

export type ButtonVariant = "primary" | "secondary" | "danger" | "ghost";
export type ButtonSize = "sm" | "md";

/** Which hover mechanism the element supports. */
export type ButtonStateSource = "aria" | "css";

const BASE =
  "inline-flex items-center justify-center gap-2 rounded-md font-medium transition-colors " +
  "disabled:cursor-not-allowed disabled:opacity-50";

const SIZES: Record<ButtonSize, string> = {
  sm: "px-3 py-1.5 text-sm",
  md: "px-4 py-2 text-sm",
};

// The resting appearance, and the colour hover moves it to. The prefix is applied below rather
// than written into these strings, so the two elements cannot drift to different hover colours.
const VARIANTS: Record<ButtonVariant, { rest: string; hover: string }> = {
  primary: { rest: "bg-accent text-accent-fg", hover: "bg-accent-hover" },
  secondary: { rest: "border border-line bg-surface text-fg", hover: "bg-surface-muted" },
  danger: { rest: "bg-danger text-danger-fg", hover: "bg-danger-hover" },
  ghost: { rest: "text-fg", hover: "bg-surface-muted" },
};

export function buttonClass(
  variant: ButtonVariant,
  size: ButtonSize,
  states: ButtonStateSource,
): string {
  const { rest, hover } = VARIANTS[variant];
  const prefix = states === "aria" ? "hovered:" : "hover:";
  const pressed = states === "aria" ? " pressed:opacity-90" : " active:opacity-90";

  return `${BASE}${pressed} ${SIZES[size]} ${rest} ${prefix}${hover}`;
}
