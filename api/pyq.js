import { createClient } from '@supabase/supabase-js';

const EXAM_SLUGS = {
  'BPSC': 'bpsc',
  'Railways (RRB)': 'rrb-ntpc',
  'JEE Main': 'jee-main',
  'JEE Advanced': 'jee-main',
  'NEET UG': 'neet-ug',
  'CUET UG': 'cuet-ug',
  'SSC Exams': 'ssc-cgl',
  'UPSC CSE': 'upsc-cse',
  'NDA / CDS': 'nda',
  'Banking Exams': 'ibps-sbi-banking'
};

function json(res, code, body) {
  res.status(code).setHeader('Content-Type', 'application/json').send(JSON.stringify(body));
}
function admin() {
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false }
  });
}
async function authenticate(req, db) {
  const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const { data, error } = await db.auth.getUser(token);
  if (error || !data?.user) return null;
  const { data: profile } = await db.from('profiles').select('target_exam').eq('id', data.user.id).maybeSingle();
  const slug = EXAM_SLUGS[profile?.target_exam || ''];
  if (!slug) return null;
  const { data: exam } = await db.from('exams').select('id,name,slug').eq('slug', slug).eq('is_active', true).maybeSingle();
  if (!exam) return null;
  return { userId: data.user.id, exam };
}

export default async function handler(req, res) {
  if (req.method !== 'POST') return json(res, 405, { error: 'Method not allowed' });
  const db = admin();
  const me = await authenticate(req, db);
  if (!me) return json(res, 401, { error: 'Please log in again and check your active exam.' });
  const body = req.body || {};

  if (body.action === 'list') {
    let q = db.from('questions')
      .select('id,body,options,difficulty,source,node_id')
      .eq('exam_id', me.exam.id)
      .is('mock_test_id', null)
      .order('created_at', { ascending: false })
      .limit(100);
    if (body.node_id && /^[0-9a-f-]{36}$/i.test(String(body.node_id))) q = q.eq('node_id', body.node_id);
    const { data, error } = await q;
    if (error) return json(res, 500, { error: 'Could not load PYQs.' });
    const { data: seen } = await db.from('pyq_attempts')
      .select('question_id')
      .eq('user_id', me.userId)
      .eq('exam_id', me.exam.id);
    const done = new Set((seen || []).map(x => x.question_id));
    let fresh = (data || []).filter(x => !done.has(x.id));
    if (!fresh.length) fresh = data || [];
    return json(res, 200, { exam: me.exam.name, questions: fresh.slice(0, 20) });
  }

  if (body.action === 'answer') {
    const id = String(body.question_id || '');
    const selected = Number(body.selected_option);
    if (!/^[0-9a-f-]{36}$/i.test(id) || !Number.isInteger(selected) || selected < 0 || selected > 5) {
      return json(res, 400, { error: 'Invalid answer.' });
    }
    const { data: question, error } = await db.from('questions')
      .select('id,exam_id,correct_option,explanation,options')
      .eq('id', id)
      .eq('exam_id', me.exam.id)
      .is('mock_test_id', null)
      .maybeSingle();
    if (error || !question) return json(res, 404, { error: 'Question not found for your active exam.' });
    if (selected >= question.options.length) return json(res, 400, { error: 'Choose a valid option.' });
    const correct = selected === question.correct_option;
    const seconds = Math.max(0, Math.min(36000, Math.round(Number(body.time_taken_sec) || 0)));
    const { error: saveError } = await db.from('pyq_attempts').insert({
      user_id: me.userId,
      exam_id: me.exam.id,
      question_id: question.id,
      selected_option: selected,
      is_correct: correct,
      time_taken_sec: seconds
    });
    if (saveError) return json(res, 500, { error: 'Answer could not be saved. Please retry.' });
    return json(res, 200, {
      correct,
      correct_option: question.correct_option,
      explanation: question.explanation || '',
      options: question.options
    });
  }
  return json(res, 400, { error: 'Unknown action.' });
}
