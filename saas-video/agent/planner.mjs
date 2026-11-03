// Transforme une demande utilisateur en plan de clips.
// Pas de LLM ici : le planner est déterministe, donc testable. Un LLM peut réécrire le prompt en amont.
import { STYLES, TIERS } from './config.mjs';

export const MIN_DURATION = 3;
export const MAX_DURATION = 60;

export function buildPlan({ text, style = 'realiste', durationSec = 15, tier = 'eco', aspect = '9:16' }) {
  if (typeof text !== 'string' || text.trim().length < 5) {
    throw new Error('Décrivez la vidéo (au moins 5 caractères).');
  }
  if (!(style in STYLES)) throw new Error(`Style inconnu : ${style}`);
  if (!(tier in TIERS)) throw new Error(`Tier inconnu : ${tier}`);
  if (!Number.isInteger(durationSec) || durationSec < MIN_DURATION || durationSec > MAX_DURATION) {
    throw new Error(`Durée hors limites (${MIN_DURATION} à ${MAX_DURATION} s).`);
  }

  const max = TIERS[tier].maxSecondsPerClip;
  const clipCount = Math.ceil(durationSec / max);
  const clips = [];
  let remaining = durationSec;
  for (let i = 0; i < clipCount; i++) {
    const seconds = Math.min(max, remaining);
    remaining -= seconds;
    clips.push({
      index: i + 1,
      seconds,
      tier,
      aspect,
      prompt: `${text.trim()}. Part ${i + 1} of ${clipCount}. Style: ${STYLES[style]}.`,
    });
  }
  return { totalSeconds: durationSec, tier, style, aspect, clips };
}
