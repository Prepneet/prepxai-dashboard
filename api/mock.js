/*
=====================================================================
PrepX Ai · Mock test API   POST /api/mock   { action, ... }
Actions:
  list    -> active tests (paid plans only)
  start   -> starts or resumes an attempt; returns questions WITHOUT answers
  submit  -> scores on the server; returns result and review with explanations
Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (server only)
Needs migration 003_mock_tests.sql
=====================================================================
*/
import { createClient } from '@supabase/supabase-js';

const GRACE_SEC = 90;

function json(res, code, body) {
  res.status(code).setHeader('Content-Type', 'application/json').send(JSON.stringify(body));
}

function admin() {
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

// Verifies the user from the token and reads the plan from the database.
async function who(req, adm) {
  const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const { data, error } = await adm.auth.getUser(token);
  if (error || !data?.user) return null;
  const uid = data.user.id;
  const { data: prof } = await adm.from('profiles').select('plan, plan_expires_at').eq('id', uid).maybeSingle();
  let plan = prof?.plan || 'free';
  if (plan !== 'free' && prof?.plan_expires_at && new Date(prof.plan_expires_at) < new Date()) plan = 'free';
  return { uid, paid: plan !== 'free' };
}

// Scores one attempt. Only server-side answers are trusted.
async function finalize(adm, attempt, test, qs, answers, times, submittedAt) {
  let score = 0, correct = 0, incorrect = 0, unattempted = 0;
  const subj = {};
  const review = [];
  const neg = Number(test.negative_marks);

  qs.forEach((q) => {
    const a = answers[q.id];
    const has = Number.isInteger(a) && a >= 0 && a < q.options.length;
    const s = (subj[q.subject] ||= { total: 0, correct: 0, incorrect: 0, unattempted: 0 });
    s.total++;
    if (!has) { unattempted++; s.unattempted++; }
    else if (a === q.correct_index) { correct++; s.correct++; score += Number(q.marks); }
    else { incorrect++; s.incorrect++; score -= neg; }

    review.push({
      id: q.id, position: q.position, subject: q.subject, topic: q.topic,
      question: q.question, options: q.options,
      your: has ? a : null, correct: q.correct_index,
      explanation: q.explanation || '', time_sec: Number(times[q.id] || 0),
      marks: Number(q.marks),
    });
  });

  score = Math.round(score * 100) / 100;
  const attempted = correct + incorrect;
  const accuracy = attempted ? Math.round((correct / attempted) * 100) : 0;
  const timeTaken = Math.max(0, Math.min(
    Math.round((submittedAt - new Date(attempt.started_at)) / 1000),
    test.duration_min * 60 + GRACE_SEC
  ));

  await adm.from('mock_attempts').update({
    submitted_at: submittedAt.toISOString(), score, correct, incorrect, unattempted,
    accuracy, time_taken_sec: timeTaken, subject_stats: subj, answers, times,
  }).eq('id', attempt.id);

  return {
    score, total_marks: Number(test.total_marks), correct, incorrect, unattempted,
    accuracy, time_taken_sec: timeTaken, subject_stats: subj, review,
  };
}

export default async function handler(req, res) {
  if (req.method !== 'POST') return json(res, 405, { error: 'Method not allowed' });
  const body = req.body || {};
  const adm = admin();
  const me = await who(req, adm);
  if (!me) return json(res, 401, { error: 'Please log in again.' });
  if (!me.paid) return json(res, 403, { error: 'Mock tests are part of the Plus and Pro plans.', code: 'plan_required' });

  if (body.action === 'list') {
    const { data, error } = await adm.from('mock_tests')
      .select('id, exam, title, duration_min, total_marks, negative_marks')
      .eq('is_active', true).order('created_at', { ascending: false }).limit(100);
    if (error) return json(res, 500, { error: 'Could not load tests.' });
    return json(res, 200, { tests: data || [] });
  }

  if (body.action === 'start') {
    const testId = String(body.test_id || '');
    if (!/^[0-9a-f-]{36}$/i.test(testId)) return json(res, 400, { error: 'Invalid test.' });
    const { data: test } = await adm.from('mock_tests').select('*').eq('id', testId).eq('is_active', true).maybeSingle();
    if (!test) return json(res, 404, { error: 'Test not found.' });

    const now = Date.now();
    let attempt = null;
    const { data: open } = await adm.from('mock_attempts').select('*')
      .eq('user_id', me.uid).eq('test_id', testId).is('submitted_at', null)
      .order('started_at', { ascending: false }).limit(1).maybeSingle();

    if (open) {
      const endMs = new Date(open.started_at).getTime() + test.duration_min * 60000;
      if (now > endMs + GRACE_SEC * 1000) {
        // Expired attempt: close it with the answers saved so far.
        const { data: qsx } = await adm.from('mock_questions').select('*').eq('test_id', testId);
        await finalize(adm, open, test, qsx || [], open.answers || {}, open.times || {}, new Date(endMs));
      } else {
        attempt = open;
      }
    }
    if (!attempt) {
      const { data: created, error } = await adm.from('mock_attempts')
        .insert({ user_id: me.uid, test_id: testId }).select().single();
      if (error) return json(res, 500, { error: 'Could not start the test.' });
      attempt = created;
    }

    const { data: qs } = await adm.from('mock_questions')
      .select('id, position, subject, topic, question, options, marks')
      .eq('test_id', testId).order('position');

    return json(res, 200, {
      attempt_id: attempt.id,
      started_at: attempt.started_at,
      title: test.title,
      duration_min: test.duration_min,
      total_marks: Number(test.total_marks),
      negative_marks: Number(test.negative_marks),
      questions: qs || [],
      saved_answers: attempt.answers || {},
    });
  }

  if (body.action === 'submit') {
    const attemptId = String(body.attempt_id || '');
    if (!/^[0-9a-f-]{36}$/i.test(attemptId)) return json(res, 400, { error: 'Invalid attempt.' });
    const { data: attempt } = await adm.from('mock_attempts').select('*')
      .eq('id', attemptId).eq('user_id', me.uid).is('submitted_at', null).maybeSingle();
    if (!attempt) return json(res, 404, { error: 'Attempt not found or already submitted.' });

    const { data: test } = await adm.from('mock_tests').select('*').eq('id', attempt.test_id).maybeSingle();
    const { data: qs } = await adm.from('mock_questions').select('*').eq('test_id', attempt.test_id).order('position');

    const answers = {};
    Object.entries(body.answers || {}).slice(0, 500).forEach(([k, v]) => {
      if (Number.isInteger(v)) answers[k] = v;
    });
    const times = {};
    Object.entries(body.times || {}).slice(0, 500).forEach(([k, v]) => {
      const n = Number(v);
      if (Number.isFinite(n) && n >= 0) times[k] = Math.min(Math.round(n), 36000);
    });

    const result = await finalize(adm, attempt, test, qs || [], answers, times, new Date());
    return json(res, 200, result);
  }

  return json(res, 400, { error: 'Unknown action' });
}
