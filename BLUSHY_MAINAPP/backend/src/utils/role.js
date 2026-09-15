export function normalizeRole(role, fallback = 'woman') {
  if (typeof role !== 'string') {
    return fallback;
  }

  const normalized = role.trim().toLowerCase();
  if (normalized === 'man' || normalized === 'partner') {
    return 'man';
  }

  if (normalized === 'woman' || normalized === 'girl') {
    return 'woman';
  }

  return fallback;
}

export function isWomanRole(role) {
  return normalizeRole(role) === 'woman';
}
