// Orchestrateur : demande -> plan -> contrôle quota -> génération par clip -> résultat.
import { buildPlan } from './planner.mjs';
import { QuotaManager } from './quota.mjs';

export class VideoAgent {
  constructor({ provider, quota = new QuotaManager(), maxRetries = 1, log = () => {} }) {
    this.provider = provider;
    this.quota = quota;
    this.maxRetries = maxRetries;
    this.log = log;
  }

  async run({ userId, plan, text, style, durationSec, tier, aspect }) {
    const p = buildPlan({ text, style, durationSec, tier, aspect });

    // Contrôle global avant tout appel : on vérifie le total, pas clip par clip,
    // pour ne pas générer la moitié d'une vidéo puis refuser.
    this.quota.check(userId, plan, tier, p.totalSeconds);

    const clips = [];
    for (const clip of p.clips) {
      const result = await this.#generateWithRetry(clip);
      clips.push({ ...clip, ...result });
      this.quota.consume(userId, tier, clip.seconds);
    }
    return { plan: p, clips };
  }

  async #generateWithRetry(clip) {
    let lastError;
    for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
      try {
        this.log({ event: 'attempt', clip: clip.index, attempt });
        return await this.provider.generate(clip);
      } catch (err) {
        lastError = err;
        this.log({ event: 'error', clip: clip.index, attempt, message: err.message });
      }
    }
    throw new Error(`Clip ${clip.index} en échec après ${this.maxRetries + 1} tentative(s) : ${lastError.message}`);
  }
}
