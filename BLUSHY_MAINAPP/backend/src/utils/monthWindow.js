/**
 * Pure date reasoning for the monthly reflection.
 *
 * Kept out of `monthlyInsightsService.js` deliberately: that module opens a
 * database connection on import, so a test that only wants to check a date
 * comparison would hold the process open waiting on a connection it never uses.
 */

/**
 * Whether the reporting month had already ended before this account existed.
 *
 * The monthly card reports the last *completed* calendar month, so through
 * August it reports July. Someone who installed the app in August was shown a
 * list of things she had "not logged" in a month she was never here for --
 * a statement about the app, not about her, at the top of her home page.
 *
 * An unknown or unparseable join date reports `false`. Accounts predating the
 * field would otherwise have a month they really did use silently removed,
 * which is the worse failure of the two.
 */
export function joinedAfterReportingMonth(createdAt, endDate) {
  if (!createdAt) return false;

  const created = createdAt instanceof Date ? createdAt : new Date(createdAt);
  if (Number.isNaN(created.getTime())) return false;

  const monthEndedAt = new Date(`${endDate}T23:59:59.999Z`);
  if (Number.isNaN(monthEndedAt.getTime())) return false;

  return created > monthEndedAt;
}
