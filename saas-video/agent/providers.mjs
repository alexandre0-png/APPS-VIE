// Adaptateurs vers les fournisseurs vidéo.
// Contrat commun : generate({ prompt, seconds, tier, aspect }) -> { url, provider, id }

// Fournisseur factice : aucune requête réseau, renvoie une URL de placeholder.
// Sert à tester le pipeline sans clé API ni coût.
export class MockProvider {
  constructor({ failEvery = 0 } = {}) {
    this.calls = 0;
    this.failEvery = failEvery;
  }

  async generate(job) {
    this.calls += 1;
    if (this.failEvery && this.calls % this.failEvery === 0) {
      throw new Error('Mock: échec simulé du fournisseur');
    }
    return {
      id: `mock-${this.calls}`,
      provider: 'mock',
      url: `mock://video/${encodeURIComponent(job.prompt.slice(0, 40))}-${job.seconds}s`,
    };
  }
}

// Fournisseur HTTP générique. Adapter l'URL, l'auth et les champs au fournisseur choisi
// (Kling, Veo, Runway, ou un agrégateur) en lisant leur documentation officielle.
// Ne contient volontairement aucun endpoint inventé.
export class HttpProvider {
  constructor({ baseUrl, apiKey, modelByTier, fetchImpl = fetch, timeoutMs = 120_000 }) {
    if (!baseUrl || !apiKey) throw new Error('HttpProvider: baseUrl et apiKey sont requis');
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.apiKey = apiKey;
    this.modelByTier = modelByTier;
    this.fetch = fetchImpl;
    this.timeoutMs = timeoutMs;
  }

  async generate(job) {
    const model = this.modelByTier[job.tier];
    if (!model) throw new Error(`Aucun modèle configuré pour le tier ${job.tier}`);
    const res = await this.fetch(`${this.baseUrl}/videos`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model, prompt: job.prompt, duration: job.seconds, aspect_ratio: job.aspect }),
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    if (!res.ok) throw new Error(`Fournisseur HTTP ${res.status}`);
    const data = await res.json();
    if (!data.url) throw new Error('Réponse fournisseur sans url');
    return { id: data.id, provider: 'http', url: data.url };
  }
}
