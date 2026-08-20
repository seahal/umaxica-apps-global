import type { SharedProps } from "@/types/inertia";

// Binds the Rails <-> Inertia payload contract to the adapter's own types, so `usePage()`,
// `router` callbacks and the form helpers are typed from one source instead of each call site
// restating the shape.
declare module "@inertiajs/core" {
  export interface InertiaConfig {
    sharedPageProps: SharedProps;
    // A validation failure reaches Inertia as `errors.to_hash(true).transform_values(&:first)`
    // (app/controllers/concerns/preference_sign_screen_actions.rb), so a key carries the first
    // message, not the list. This happens to match the adapter's default; it is declared because
    // it is a decision on the Rails side, not an accident.
    errorValueType: string;
  }
}
