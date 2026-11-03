import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildPlan } from './planner.mjs';
import { QuotaManager, InMemoryUsageStore } from './quota.mjs';
import { VideoAgent } from './agent.mjs';
import { MockProvider } from './providers.mjs';

const fixedNow = (iso) => () => new Date(iso);

test('planner découpe en clips de 5 s max et conserve la durée totale', () => {
  const p = buildPlan({ text: 'un barista prépare un café', durationSec: 12, tier: 'eco' });
  assert.deepEqual(p.clips.map((c) => c.seconds), [5, 5, 2]);
  assert.equal(p.totalSeconds, 12);
});

test('planner rejette les entrées invalides', () => {
  assert.throws(() => buildPlan({ text: 'ok' }), /au moins 5/);
  assert.throws(() => buildPlan({ text: 'un café', durationSec: 2 }), /Durée/);
  assert.throws(() => buildPlan({ text: 'un café', style: 'inconnu' }), /Style/);
});

test('quota : refuse si le total dépasse le quota du tier, sans consommer', () => {
  const q = new QuotaManager({ now: fixedNow('2026-11-10T10:00:00Z') });
  assert.throws(() => q.check('u1', 'essentiel', 'eco', 61), { code: 'quota_exceeded' });
  assert.equal(q.remaining('u1', 'essentiel').seconds.eco, 60);
});

test('quota : tier absent de l\'offre refusé', () => {
  const q = new QuotaManager({ now: fixedNow('2026-11-10T10:00:00Z') });
  assert.throws(() => q.check('u1', 'essentiel', 'premium', 5), { code: 'tier_not_in_plan' });
});

test('quota : plafond quotidien puis remise à zéro le lendemain', () => {
  let now = new Date('2026-11-10T10:00:00Z');
  const q = new QuotaManager({ now: () => now });
  for (let i = 0; i < 3; i++) { q.check('u1', 'essentiel', 'eco', 5); q.consume('u1', 'eco', 5); }
  assert.throws(() => q.check('u1', 'essentiel', 'eco', 5), { code: 'daily_cap' });
  now = new Date('2026-11-11T10:00:00Z');
  assert.doesNotThrow(() => q.check('u1', 'essentiel', 'eco', 5));
});

test('quota : remise à zéro mensuelle', () => {
  let now = new Date('2026-11-10T10:00:00Z');
  const q = new QuotaManager({ now: () => now, store: new InMemoryUsageStore() });
  q.check('u1', 'essentiel', 'eco', 60); q.consume('u1', 'eco', 60);
  now = new Date('2026-12-01T10:00:00Z');
  assert.equal(q.remaining('u1', 'essentiel').seconds.eco, 60);
});

test('agent : génère tous les clips et consomme le quota', async () => {
  const q = new QuotaManager({ now: fixedNow('2026-11-10T10:00:00Z') });
  const agent = new VideoAgent({ provider: new MockProvider(), quota: q });
  const r = await agent.run({ userId: 'u1', plan: 'essentiel', text: 'un barista prépare un café', durationSec: 10, tier: 'eco' });
  assert.equal(r.clips.length, 2);
  assert.ok(r.clips.every((c) => c.url.startsWith('mock://')));
  assert.equal(q.remaining('u1', 'essentiel').seconds.eco, 50);
});

test('agent : un échec de clip ne consomme pas de quota pour les clips non générés', async () => {
  const q = new QuotaManager({ now: fixedNow('2026-11-10T10:00:00Z') });
  const agent = new VideoAgent({ provider: new MockProvider({ failEvery: 1 }), quota: q, maxRetries: 0 });
  await assert.rejects(
    agent.run({ userId: 'u1', plan: 'essentiel', text: 'un barista prépare un café', durationSec: 10, tier: 'eco' }),
    /en échec/,
  );
  assert.equal(q.remaining('u1', 'essentiel').seconds.eco, 60);
});

test('agent : un retry réussit après un échec transitoire', async () => {
  const q = new QuotaManager({ now: fixedNow('2026-11-10T10:00:00Z') });
  const agent = new VideoAgent({ provider: new MockProvider({ failEvery: 2 }), quota: q, maxRetries: 1 });
  const r = await agent.run({ userId: 'u1', plan: 'essentiel', text: 'un barista prépare un café', durationSec: 5, tier: 'eco' });
  assert.equal(r.clips.length, 1);
});
