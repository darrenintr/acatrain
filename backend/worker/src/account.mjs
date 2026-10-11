import { assert } from './content.mjs';

// Only learner-controlled presentation fields live here. Authentication,
// entitlements and roles MUST come from their authoritative services.
const PROFILE_FIELDS = ['appearance', 'displayName', 'languageCode'];
export function validateProfile(value) {
  assert(value && typeof value === 'object' && !Array.isArray(value),
    'profile must be an object');
  const fields = Object.keys(value).sort();
  assert(fields.length === PROFILE_FIELDS.length &&
    fields.every((field, i) => field === PROFILE_FIELDS[i]),
    'profile must contain only displayName, languageCode and appearance');
  assert(typeof value.displayName === 'string' &&
    value.displayName.trim().length >= 1 &&
    value.displayName.length <= 80 &&
    !/[\u0000-\u001f\u007f]/.test(value.displayName),
    'displayName must be 1-80 characters without control characters');
  assert(['en', 'zh'].includes(value.languageCode),
    'languageCode must be en or zh');
  assert(['system', 'light', 'dark'].includes(value.appearance),
    'appearance must be system, light or dark');
  return {
    displayName: value.displayName.trim(),
    languageCode: value.languageCode,
    appearance: value.appearance,
  };
}

export async function enforceRateLimit(binding, key) {
  if (!binding) return; // Local tests/dev; production config binds rate limiters.
  const result = await binding.limit({ key });
  assert(result?.success === true, 'Too many requests. Try again shortly.', 429);
}
