import config from "../../config.js";
import { test as setup, expect } from '@playwright/test';
import { execSync } from "child_process";

const cwd = process.cwd();
const dbPath = `${cwd}/data/data.sqlite`;
const oldFixtures = `${cwd}/cypress/fixtures`;
const userFile = `${cwd}/tests/e2e/.auth/user.json`;

setup('signup test user', async ({ page }) => {
  // Create DB and tables
  execSync(`sqlite3 ${dbPath} < ${cwd}/src/shared/db.sql`);
  // Delete test user data from  SQLite
  execSync(`sqlite3 ${dbPath} < ${oldFixtures}/deleteTestData.sql`);
  await page.goto("/");
  await page.waitForLoadState('domcontentloaded');

  await page.locator('input[placeholder="Email"]').fill('cypress@testing.com');
  await page.locator('input[placeholder="Password"]').fill('testing');
  await page.locator('button:has-text("Signup")').click();

  await page.evaluate(() => {
    console.log('setting localStorage');
    localStorage.setItem('gingko-session-storage', JSON.stringify({ "email": "cypress@testing.com", "language": "en" }));
    console.log('localStorage set', localStorage.getItem('gingko-session-storage'));
    return true;
  });

  // Check if cookies are set in the browser context
  const cookies = await page.context().cookies();
  expect(cookies).not.toEqual([]);

  await page.context().storageState({ path: userFile });
});