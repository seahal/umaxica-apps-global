// The core/dev host serves one page: the React Aria probe used to verify that the component
// library renders under this surface's build. The probe is a named export, so it is adapted to the
// default export an Inertia page resolves to.
export { ReactAriaProbe as default } from "@/features/react_aria_probe/ReactAriaProbe";
