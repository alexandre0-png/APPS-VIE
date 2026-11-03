#!/usr/bin/env node
// Usage :
//   node saas-video/agent/cli.mjs "un barista prépare un café" --style realiste --duration 15 --plan pro --tier eco
// Sans variables d'environnement, le fournisseur factice est utilisé (aucun coût, aucun appel réseau).
// Pour un vrai fournisseur : VIDEO_API_BASE_URL, VIDEO_API_KEY, et les modèles VIDEO_MODEL_ECO / _STANDARD / _PREMIUM.
import { parseArgs } from 'node:util';
import { VideoAgent } from './agent.mjs';
import { MockProvider, HttpProvider } from './providers.mjs';

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    style: { type: 'string', default: 'realiste' },
    duration: { type: 'string', default: '15' },
    tier: { type: 'string', default: 'eco' },
    plan: { type: 'string', default: 'essentiel' },
    user: { type: 'string', default: 'demo-user' },
  },
});

function makeProvider() {
  const { VIDEO_API_BASE_URL, VIDEO_API_KEY, VIDEO_MODEL_ECO, VIDEO_MODEL_STANDARD, VIDEO_MODEL_PREMIUM } = process.env;
  if (!VIDEO_API_BASE_URL || !VIDEO_API_KEY) return new MockProvider();
  return new HttpProvider({
    baseUrl: VIDEO_API_BASE_URL,
    apiKey: VIDEO_API_KEY,
    modelByTier: { eco: VIDEO_MODEL_ECO, standard: VIDEO_MODEL_STANDARD, premium: VIDEO_MODEL_PREMIUM },
  });
}

const text = positionals.join(' ');
const agent = new VideoAgent({
  provider: makeProvider(),
  log: (e) => process.stderr.write(JSON.stringify(e) + '\n'),
});

try {
  const result = await agent.run({
    userId: values.user,
    plan: values.plan,
    text,
    style: values.style,
    durationSec: Number(values.duration),
    tier: values.tier,
  });
  console.log(JSON.stringify(result, null, 2));
} catch (err) {
  console.error(`Erreur : ${err.message}`);
  process.exitCode = 1;
}
