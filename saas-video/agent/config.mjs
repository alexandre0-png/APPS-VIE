// Offres et tiers de génération. Les chiffres reprennent la maquette (saas-video/index.html).
// Un tier = un niveau de coût/qualité côté fournisseur vidéo.
export const TIERS = {
  eco:      { label: 'Éco 720p',      maxSecondsPerClip: 5 },
  standard: { label: 'Standard 720p', maxSecondsPerClip: 5 },
  premium:  { label: 'Premium 1080p', maxSecondsPerClip: 5 },
};

export const PLANS = {
  essentiel: { quota: { eco: 60 },                          maxPerDay: 3,  watermark: true,  tiktok: false },
  pro:       { quota: { eco: 120, standard: 30 },           maxPerDay: 10, watermark: false, tiktok: true  },
  studio:    { quota: { eco: 120, standard: 60, premium: 60 }, maxPerDay: 20, watermark: false, tiktok: true },
};

export const STYLES = {
  realiste: 'photorealistic, natural lighting, cinematic camera, realistic textures',
  technique: 'clean technical illustration style, clear labels, smooth animated diagram, neutral background',
  tendance: 'vertical social video, dynamic cuts, bold colors, fast-paced energy',
};
