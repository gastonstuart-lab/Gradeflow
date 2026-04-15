import { test, expect } from "@playwright/test";
import {
  activateControl,
  ensureDemoSignedIn,
  expectSeatingSurface,
  escapeRegex,
  gotoRoot,
  openFirstClassWorkspace,
} from "./helpers";

test("Seating: room setup save flow works from the toolbar", async ({
  page,
}) => {
  test.setTimeout(180_000);

  const roomName = `Room ${Date.now()}`;

  await gotoRoot(page);
  await ensureDemoSignedIn(page);

  await openFirstClassWorkspace(page);
  await activateControl(
    page.getByRole("button", { name: /^Seating\b/i }).first(),
  );
  await expectSeatingSurface(page);

  await expect(
    page.getByRole("button", { name: /^New layout$/i }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: /^Duplicate$/i }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: /^Room setups$/i }),
  ).toBeVisible();

  await activateControl(
    page.getByRole("button", { name: /^Room setups$/i }).first(),
  );
  await expect(page.getByText("Room setups", { exact: true })).toBeVisible();

  await activateControl(
    page.getByRole("button", { name: /^Save current room$/i }).first(),
  );
  const roomNameField = page.getByRole("textbox", { name: /^Room name$/i });
  await expect(roomNameField).toBeVisible();
  await roomNameField.fill(roomName);

  await activateControl(
    page.getByRole("button", { name: /^Save room$/i }).first(),
  );

  await expect(
    page
      .getByRole("group", {
        name: new RegExp(`${escapeRegex(roomName)}.*Linked here`, "i"),
      })
      .first(),
  ).toBeVisible();

  await activateControl(page.getByRole("button", { name: /^Close$/i }).first());
  await expect(
    page.getByText(new RegExp(`Room:\\s*${escapeRegex(roomName)}`)),
  ).toBeVisible();
});
