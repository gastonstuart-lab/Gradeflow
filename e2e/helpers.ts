import { expect, type Locator, type Page } from "@playwright/test";

export const dashboardPath = "/dashboard";
export const classesPath = "/classes";

async function gotoWithRetry(page: Page, path: string, attempts = 3) {
  let lastError: unknown;
  for (let i = 0; i < attempts; i += 1) {
    try {
      await page.goto(path, { waitUntil: "commit" });
      return;
    } catch (error) {
      lastError = error;
      const message = String((error as Error)?.message ?? error);
      if (!/ERR_CONNECTION_REFUSED/i.test(message) || i === attempts - 1) {
        throw error;
      }
      await page.waitForTimeout(1_500);
      await page.goto("/").catch(() => undefined);
      await ensureFlutterSemantics(page).catch(() => undefined);
    }
  }

  throw lastError;
}

export async function ensureFlutterSemantics(page: Page) {
  if (page.isClosed()) {
    return;
  }

  const enable = page
    .locator('button[aria-label="Enable accessibility"]')
    .first();
  const canEnable = await enable
    .isVisible({ timeout: 2_000 })
    .catch(() => false);
  if (canEnable) {
    await enable.click({ timeout: 10_000 }).catch(() => undefined);
  }

  await page
    .waitForSelector("flt-semantics-host", { timeout: 20_000 })
    .catch(() => undefined);
}

export async function gotoRoot(page: Page) {
  await gotoWithRetry(page, "/");
  await ensureFlutterSemantics(page);
}

export async function activateControl(target: Locator) {
  if (target.page().isClosed()) {
    return;
  }

  await target.scrollIntoViewIfNeeded().catch(() => undefined);

  const clicked = await target
    .click({ timeout: 8_000 })
    .then(() => true)
    .catch(() => false);
  if (!clicked && !target.page().isClosed()) {
    const pressed = await target
      .press("Enter")
      .then(() => true)
      .catch(() => false);
    if (!pressed && !target.page().isClosed()) {
      await target.click({ force: true }).catch(() => undefined);
    }
  }
}

async function anyLocatorVisible(
  locators: Locator[],
  timeout = 3_000,
): Promise<boolean> {
  for (const locator of locators) {
    if (
      await locator
        .first()
        .isVisible({ timeout })
        .catch(() => false)
    ) {
      return true;
    }
  }
  return false;
}

export async function ensureDemoSignedIn(page: Page) {
  await ensureFlutterSemantics(page);

  const currentAppPath = () => {
    try {
      const url = new URL(page.url());
      if (url.hash.startsWith("#/")) {
        return url.hash.slice(1).split("?")[0];
      }
      return url.pathname;
    } catch {
      return "";
    }
  };

  const isSignedInRoute = () =>
    /^\/(?:dashboard|os\/home|os\/planner|os\/class\/[^/?#]+|class\/[^/?#]+)(?:\/|$)/i.test(
      currentAppPath(),
    );

  const isSignedInSurfaceVisible = async () =>
    (await anyLocatorVisible(
      [
        page.getByText(/Command deck|Teacher cockpit|Planner/i).first(),
        page.getByRole("button", { name: /^Classes\b/i }).last(),
        page.getByRole("button", { name: /^Planner\b/i }).last(),
        page.getByRole("button", { name: /^Home$/i }).first(),
        page.getByText(/HOME STAGE|Class workspace|Loading workspace shell/i).first(),
        page.getByRole("button", { name: /^Teach Mode$/i }).first(),
      ],
      1_000,
    )) ||
    /HOME STAGE|Planner|Class workspace|GradeFlow OS|Pinned apps|Class spaces/i.test(
      await page
        .locator("body")
        .innerText({ timeout: 1_000 })
        .catch(() => ""),
    );

  if (isSignedInRoute()) {
    return;
  }

  // Fast-path recovery for sessions that are already authenticated but landed
  // on a transient shell route that does not satisfy older dashboard checks.
  await page.goto('/os/home').catch(() => undefined);
  await ensureFlutterSemantics(page);
  if (isSignedInRoute() || (await isSignedInSurfaceVisible())) {
    return;
  }

  const demo = page.getByRole("button", { name: /^Try Demo Account$/i }).first();
  const enteringWorkspace = page
    .getByRole("button", { name: /^Entering workspace\.\.\.$/i })
    .first();
  const loadingShell = page.getByText(/Loading workspace shell/i).first();
  let loadingShellVisibleSince: number | null = null;
  const deadline = Date.now() + 180_000;

  while (Date.now() < deadline) {
    await ensureFlutterSemantics(page);

    if (isSignedInRoute() || (await isSignedInSurfaceVisible())) {
      return;
    }

    const demoVisible = await demo.isVisible({ timeout: 1_000 }).catch(() => false);
    if (demoVisible) {
      const demoEnabled = await demo.isEnabled().catch(() => false);
      if (demoEnabled) {
        await activateControl(demo);
        await ensureFlutterSemantics(page);
        if (isSignedInRoute() || (await isSignedInSurfaceVisible())) {
          return;
        }
      }
    }

    const isTransitioning =
      (await enteringWorkspace.isVisible({ timeout: 500 }).catch(() => false)) ||
      (await loadingShell.isVisible({ timeout: 500 }).catch(() => false));

    if (isTransitioning) {
      loadingShellVisibleSince ??= Date.now();
    } else {
      loadingShellVisibleSince = null;
    }

    if (
      isTransitioning &&
      loadingShellVisibleSince != null &&
      Date.now() - loadingShellVisibleSince > 20_000
    ) {
      await page.goto('/os/home').catch(() => undefined);
      await ensureFlutterSemantics(page);
      if (isSignedInRoute() || (await isSignedInSurfaceVisible())) {
        return;
      }
    }

    await page.waitForTimeout(isTransitioning ? 1_500 : 1_000);
  }

  throw new Error(`Demo sign-in did not complete. Last URL=${page.url()}`);
}

export async function expectDashboardShell(page: Page) {
  const attentionButton = page.getByRole("button", {
    name: "Attention center",
  });
  const hasAttention = await attentionButton
    .isVisible({ timeout: 5_000 })
    .catch(() => false);
  if (hasAttention) {
    await expect(attentionButton).toBeVisible({ timeout: 60_000 });
  }

  const requiredNavVariants: RegExp[] = [
    /^Home\b/i,
    /^Planner\b/i,
    /^Classes\b/i,
    /^Theme\b/i,
    /^All Apps\b/i,
  ];

  for (const pattern of requiredNavVariants) {
    await expect(
      page.getByRole("button", { name: pattern }).last(),
    ).toBeVisible({ timeout: 60_000 });
  }
}

export async function gotoDashboard(page: Page) {
  await gotoWithRetry(page, dashboardPath);
  await ensureFlutterSemantics(page);
  await expectDashboardShell(page);
}

export async function gotoClasses(page: Page) {
  const isClassesSurfaceVisible = async () => {
    const bodyText = await page
      .locator("body")
      .innerText({ timeout: 1_000 })
      .catch(() => "");
    if (/Classes workspace|Class spaces|Create Class|Local import ready/i.test(bodyText)) {
      return true;
    }

    const classesRoleHeading = page.getByRole("heading", {
      name: /Classes workspace/i,
    });
    if (
      await classesRoleHeading
        .isVisible({ timeout: 2_000 })
        .catch(() => false)
    ) {
      return true;
    }

    const importButton = page.getByRole("button", { name: /^Import$/i });
    if (await importButton.isVisible({ timeout: 2_000 }).catch(() => false)) {
      return true;
    }

    const classesHeading = page.getByText("Classes workspace", { exact: true });
    if (await classesHeading.isVisible({ timeout: 2_000 }).catch(() => false)) {
      return true;
    }

    const classSpacesHeading = page.getByText("Class spaces", {
      exact: true,
    });
    if (
      await classSpacesHeading.isVisible({ timeout: 2_000 }).catch(() => false)
    ) {
      return true;
    }

    const openClasses = page.getByRole("button", { name: /^Open classes$/i });
    if (await openClasses.isVisible({ timeout: 2_000 }).catch(() => false)) {
      return true;
    }

    const classCard = page
      .getByRole("group", {
        name: /Grade .*students/i,
      })
      .first();
    return classCard.isVisible({ timeout: 2_000 }).catch(() => false);
  };

  await gotoWithRetry(page, classesPath);
  await ensureFlutterSemantics(page);

  if (!(await isClassesSurfaceVisible())) {
    const openClasses = page.getByRole("button", { name: /^Open classes$/i });
    if (await openClasses.isVisible({ timeout: 5_000 }).catch(() => false)) {
      await openClasses.click();
    } else {
      const classesNav = page
        .getByRole("button", { name: /^(Classes|Class spaces)\b/i })
        .last();
      if (await classesNav.isVisible({ timeout: 5_000 }).catch(() => false)) {
        await classesNav.click();
      } else {
        await gotoWithRetry(page, '/os/home');
        await ensureFlutterSemantics(page);
        const osHomeClasses = page
          .getByRole("button", { name: /^(Classes|Class spaces)\b/i })
          .last();
        if (
          await osHomeClasses.isVisible({ timeout: 5_000 }).catch(() => false)
        ) {
          await osHomeClasses.click();
        } else {
          await gotoWithRetry(page, classesPath);
        }
      }
    }
    await ensureFlutterSemantics(page);
  }

  await expect.poll(isClassesSurfaceVisible, { timeout: 60_000 }).toBeTruthy();

}

export async function openFirstClassWorkspace(page: Page) {
  const classSurfaceButton = page
    .getByRole("button", {
      name: /^(Gradebook|Seating|Export|Reports|Open Gradebook|Open Seating|Open Export)\b/i,
    })
    .first();
  const classSurfaceTab = page
    .getByRole("tab", { name: /^(Overview|Gradebook|Seating|Students|Export)\b/i })
    .first();

  const isOnClassDetailSurface = async () => {
    if (
      await classSurfaceButton.isVisible({ timeout: 2_000 }).catch(() => false)
    ) {
      return true;
    }
    return classSurfaceTab.isVisible({ timeout: 2_000 }).catch(() => false);
  };

  const gatherDiag = async () => {
    const buttons = page.getByRole("button");
    const count = await buttons.count();
    const labels: string[] = [];
    for (let i = 0; i < Math.min(count, 16); i += 1) {
      const text = (
        await buttons
          .nth(i)
          .innerText()
          .catch(() => "")
      )
        .replace(/\s+/g, " ")
        .trim();
      if (text) {
        labels.push(text);
      }
    }
    return { url: page.url(), labels };
  };

  const tryActivate = async (
    target: { click: any; press?: any; scrollIntoViewIfNeeded?: any },
    withEnterFallback = true,
  ) => {
    if (withEnterFallback) {
      await activateControl(target as Locator);
    } else {
      if (target.scrollIntoViewIfNeeded) {
        await target.scrollIntoViewIfNeeded().catch(() => undefined);
      }
      const clicked = await target
        .click({ timeout: 8_000 })
        .then(() => true)
        .catch(() => false);
      if (!clicked) {
        await target.click({ force: true });
      }
    }

    await ensureFlutterSemantics(page);
    return isOnClassDetailSurface();
  };

  if (await isOnClassDetailSurface()) {
    return;
  }

  await gotoClasses(page);

  if (await isOnClassDetailSurface()) {
    return;
  }

  const classEntries = page.getByRole("group", {
    name: /Open class workspace|Grade .*students/i,
  });
  const hasClassEntry = await classEntries
    .first()
    .isVisible({ timeout: 8_000 })
    .catch(() => false);

  if (!hasClassEntry) {
    const homeClassButton = page
      .getByRole("button", { name: /^Grade\s+\d+/i })
      .first();
    if (await homeClassButton.isVisible({ timeout: 8_000 }).catch(() => false)) {
      await activateControl(homeClassButton);
      await ensureFlutterSemantics(page);
      if (await isOnClassDetailSurface()) {
        return;
      }
    }
  }

  await expect(classEntries.first()).toBeVisible({ timeout: 60_000 });
  const classEntry = classEntries.first();

  const inEntryOpenClassText = classEntry
    .getByText(/Open class workspace/i)
    .first();
  if (
    await inEntryOpenClassText.isVisible({ timeout: 5_000 }).catch(() => false)
  ) {
    if (await tryActivate(inEntryOpenClassText, false)) {
      return;
    }
  }

  const inEntryOpenClassButton = classEntry
    .getByRole("button", { name: /^Open class$/i })
    .first();
  if (
    await inEntryOpenClassButton
      .isVisible({ timeout: 5_000 })
      .catch(() => false)
  ) {
    if (await tryActivate(inEntryOpenClassButton)) {
      return;
    }
  }

  const globalOpenClassButton = page
    .getByRole("button", { name: /^Open class$/i })
    .first();
  if (
    await globalOpenClassButton.isVisible({ timeout: 5_000 }).catch(() => false)
  ) {
    if (await tryActivate(globalOpenClassButton)) {
      return;
    }
  }

  const showMenu = classEntry
    .getByRole("button", { name: /^Show menu$/i })
    .first();
  if (await showMenu.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await tryActivate(showMenu, false);
    const openFromMenu = page
      .getByRole("menuitem", { name: /Open class|Open workspace|Open/i })
      .first();
    if (await openFromMenu.isVisible({ timeout: 4_000 }).catch(() => false)) {
      if (await tryActivate(openFromMenu, false)) {
        return;
      }
    }
  }

  if (await tryActivate(classEntry)) {
    return;
  }

  const diag = await gatherDiag();
  throw new Error(
    `Class-entry transition did not reach class detail. URL=${diag.url}; buttons=${diag.labels.join(" | ")}`,
  );
}

export async function expectExportSurface(page: Page) {
  const exportReady = [
    page.getByText(/Class export|Student report|All-classes export/i).first(),
    page.getByRole("button", { name: /^Preview (CSV|PDF)$/i }).first(),
    page.getByRole("button", { name: /^Export (CSV|XLSX|PDF)$/i }).first(),
  ];
  await expect
    .poll(() => anyLocatorVisible(exportReady, 1_000), { timeout: 60_000 })
    .toBeTruthy();
}

export async function expectSeatingSurface(page: Page) {
  const seatingReady = [
    page.getByRole("heading", { name: /Seating/i }),
    page.getByRole("checkbox", { name: /^Edit room$/i }),
    page.getByRole("button", { name: /^Preview PDF$/i }),
  ];
  await expect
    .poll(() => anyLocatorVisible(seatingReady, 1_000), { timeout: 60_000 })
    .toBeTruthy();
}

export async function expectGradebookSurface(page: Page) {
  const gradebookReady = [
    page.getByRole("button", { name: /^Clear score$/i }),
    page.getByRole("button", { name: /^Quick grade$/i }),
    page.getByRole("button", { name: /^Undo last (score )?change$/i }),
  ];
  await expect
    .poll(() => anyLocatorVisible(gradebookReady, 1_000), { timeout: 60_000 })
    .toBeTruthy();
}

async function discoverPrimaryClassId(page: Page): Promise<string | null> {
  await gotoWithRetry(page, '/os/home').catch(() => undefined);
  await ensureFlutterSemantics(page);

  const classLaunchButton = page
    .getByRole('button', { name: /^Grade\s+\w+/i })
    .first();

  if (
    await classLaunchButton
      .isVisible({ timeout: 10_000 })
      .catch(() => false)
  ) {
    await activateControl(classLaunchButton);
    await ensureFlutterSemantics(page);
    const match = page.url().match(/\/os\/class\/([^/?#]+)/i);
    if (match?.[1]) {
      return match[1];
    }
  }

  // Fallback via classes route if OS-home launch card is not present.
  await gotoWithRetry(page, classesPath).catch(() => undefined);
  await ensureFlutterSemantics(page);
  const classesRouteMatch = page.url().match(/\/os\/class\/([^/?#]+)/i);
  if (classesRouteMatch?.[1]) {
    return classesRouteMatch[1];
  }

  return null;
}

async function isOnClassSurface(page: Page, suffix: string) {
  if (suffix === "export") {
    return anyLocatorVisible(
      [
        page.getByText(/Class export|Student report|All-classes export/i).first(),
        page.getByRole("button", { name: /^Preview (CSV|PDF)$/i }).first(),
        page.getByRole("button", { name: /^Export (CSV|XLSX|PDF)$/i }).first(),
      ],
      3_000,
    );
  }

  if (suffix === "seating") {
    return anyLocatorVisible(
      [
        page.getByRole("heading", { name: /Seating/i }),
        page.getByRole("checkbox", { name: /^Edit room$/i }),
        page.getByRole("button", { name: /^Preview PDF$/i }),
      ],
      3_000,
    );
  }

  if (suffix === "gradebook") {
    return anyLocatorVisible(
      [
        page.getByRole("button", { name: /^Clear score$/i }),
        page.getByRole("button", { name: /^Quick grade$/i }),
        page.getByRole("button", { name: /^Undo( last (score )?change)?$/i }),
      ],
      3_000,
    );
  }

  return (
    /\/class\/[^/]+\//.test(page.url()) || /\/classes(?:\?|$)/.test(page.url())
  );
}

export async function gotoDemoClassRoute(page: Page, suffix: string) {
  const routesForClass = (classId: string) => {
    const directToolRouteBySuffix: Record<string, string> = {
      gradebook: `/class/${classId}/gradebook`,
      seating: `/class/${classId}/seating`,
      export: `/class/${classId}/export`,
    };

    return [
      directToolRouteBySuffix[suffix],
      `/os/class/${classId}`,
      `/class/${classId}`,
    ].filter((route): route is string => !!route);
  };

  const tryRoutes = async (routes: string[]) => {
    const waitForTargetSurface = async () => {
      try {
        if (suffix === "export") {
          await expectExportSurface(page);
          return true;
        }
        if (suffix === "seating") {
          await expectSeatingSurface(page);
          return true;
        }
        if (suffix === "gradebook") {
          await expectGradebookSurface(page);
          return true;
        }
        return isOnClassSurface(page, suffix);
      } catch {
        return false;
      }
    };

    for (const route of routes) {
      await gotoWithRetry(page, route).catch(() => undefined);
      await ensureFlutterSemantics(page);
      if (await waitForTargetSurface()) {
        return true;
      }
    }
    return false;
  };

  if (await tryRoutes(routesForClass('demo-class-1'))) {
    return;
  }

  const discoveredClassId = await discoverPrimaryClassId(page);
  if (
    discoveredClassId != null &&
    discoveredClassId !== 'demo-class-1' &&
    await tryRoutes(routesForClass(discoveredClassId))
  ) {
    return;
  }

  for (const route of routesForClass('demo-class-1')) {
    await gotoWithRetry(page, route).catch(() => undefined);
    await ensureFlutterSemantics(page);
    if (await isOnClassSurface(page, suffix)) {
      if (suffix === "export") {
        await expectExportSurface(page);
        return;
      }
      if (suffix === "seating") {
        await expectSeatingSurface(page);
        return;
      }
      if (suffix === "gradebook") {
        await expectGradebookSurface(page);
        return;
      }
      return;
    }
  }

  if (suffix === "export") {
    await expectExportSurface(page);
    return;
  }

  if (suffix === "seating") {
    await expectSeatingSurface(page);
    return;
  }

  if (suffix === "gradebook") {
    await expectGradebookSurface(page);
    return;
  }

  await expect
    .poll(() => isOnClassSurface(page, suffix), { timeout: 60_000 })
    .toBeTruthy();
}

export function escapeRegex(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export async function expectFeedbackMessage(
  page: Page,
  messagePattern: RegExp,
  timeout = 30_000,
) {
  await expect(page.getByText(messagePattern).first()).toBeVisible({ timeout });
}
