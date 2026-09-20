// Boots a Stimulus application over a fixture so a controller connects through the runtime

import { Application } from "@hotwired/stimulus";

// Mounts the fixture, registers each controller under its identifier, and
// resolves once the runtime has connected them; stop the application in afterEach
export async function mountControllers(html, controllers) {
  document.body.innerHTML = html;
  const application = new Application();
  for (const [identifier, controller] of Object.entries(controllers)) {
    application.register(identifier, controller);
  }
  await application.start();
  return application;
}

export function unmount(application) {
  application?.stop();
  document.body.innerHTML = "";
}
