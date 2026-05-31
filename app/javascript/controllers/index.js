import { application } from "controllers/application";

const controllers = import.meta.glob("./**/*_controller.js", { eager: true });

for (const [path, module] of Object.entries(controllers)) {
  const controllerName = path
    .replace("./", "")
    .replace("_controller.js", "")
    .replaceAll("_", "-")
    .replaceAll("/", "--");

  application.register(controllerName, module.default);
}
