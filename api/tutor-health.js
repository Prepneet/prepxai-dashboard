// Public, non-secret readiness check for the Prep Ai tutor.
// This reveals only whether required server configuration is present, never values.
export default function handler(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ ready: false, error: 'Method not allowed' });
  }
  const ready = Boolean(
    process.env.SUPABASE_URL &&
    process.env.SUPABASE_SERVICE_ROLE_KEY &&
    process.env.ANTHROPIC_API_KEY
  );
  res.setHeader('Cache-Control', 'no-store, max-age=0');
  return res.status(200).json({
    ready,
    model: 'claude-haiku-5-5',
    message: ready ? 'Tutor configuration is present.' : 'Tutor server configuration is incomplete.'
  });
}
