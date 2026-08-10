import "../application";
import { registerOfflineServiceWorker } from "../../pwa/register";

// Registered here rather than in ../application so that core/dev, which shares that module, does not
// try to register a worker its origin does not serve. See adr/pwa-offline-route-exception.md.
void registerOfflineServiceWorker();
