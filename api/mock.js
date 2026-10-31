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
const EXAM_SLUGS = {
  'BPSC':'bpsc','bpsc':'bpsc',
  'Railways (RRB)':'rrb-ntpc','rrb-ntpc':'rrb-ntpc','rrb':'rrb-ntpc','railways':'rrb-ntpc','railway':'rrb-ntpc','ntpc':'rrb-ntpc',
  'Bihar Police':'bihar-police','bihar-police':'bihar-police',
  'JEE Main':'jee-main','jee-main':'jee-main','jee':'jee-main','jee main':'jee-main','jee mains':'jee-main','jeem':'jee-main',
  'JEE Advanced':'jee-advanced','jee-advanced':'jee-advanced','jee advanced':'jee-advanced','jeea':'jee-advanced',
  'NEET UG':'neet-ug','neet-ug':'neet-ug','neet':'neet-ug','neet ug':'neet-ug',
  'CUET UG':'cuet-ug','cuet-ug':'cuet-ug','cuet':'cuet-ug','cuet ug':'cuet-ug',
  'SSC Exams':'ssc-cgl','ssc-cgl':'ssc-cgl','ssc':'ssc-cgl','ssc exams':'ssc-cgl','ssc cgl':'ssc-cgl',
  'UPSC CSE':'upsc-cse','upsc-cse':'upsc-cse','upsc':'upsc-cse','upsc cse':'upsc-cse','ias':'upsc-cse',
  'NDA':'nda','nda':'nda','NDA / CDS':'nda','nda-cds':'nda',
  'CDS':'cds','cds':'cds',
  'Banking Exams':'ibps-sbi-banking','ibps-sbi-banking':'ibps-sbi-banking','banking':'ibps-sbi-banking','ibps':'ibps-sbi-banking','sbi':'ibps-sbi-banking','bank':'ibps-sbi-banking'
};

const EXAM_KEY_BY_SLUG = {
  'bpsc':'BPSC',
  'rrb-ntpc':'Railways (RRB)',
  'bihar-police':'Bihar Police',
  'jee-main':'JEE Main',
  'jee-advanced':'JEE Advanced',
  'neet-ug':'NEET UG',
  'cuet-ug':'CUET UG',
  'ssc-cgl':'SSC Exams',
  'upsc-cse':'UPSC CSE',
  'nda':'NDA',
  'cds':'CDS',
  'ibps-sbi-banking':'Banking Exams'
};

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
  const { data: prof } = await adm.from('profiles').select('plan, plan_expires_at, target_exam').eq('id', uid).maybeSingle();
  let plan = prof?.plan || 'free';
  if (plan !== 'free' && prof?.plan_expires_at && new Date(prof.plan_expires_at) < new Date()) plan = 'free';
  const slug = EXAM_SLUGS[prof?.target_exam || ''];
  if (!slug) return null;
  const { data: exam } = await adm.from('exams').select('id,name,slug').eq('slug', slug).eq('is_active', true).maybeSingle();
  if (!exam) return null;
  return { uid, paid: plan !== 'free', target_exam: EXAM_KEY_BY_SLUG[slug] || prof.target_exam, exam };
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

  if (body.action === 'generate_sunday') {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit'
    }).formatToParts(new Date());
    const part = (type) => parts.find(x => x.type === type)?.value;
    const year = Number(part('year')), month = Number(part('month')), day = Number(part('day'));
    const localDay = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
    if (![0, 5, 6].includes(localDay)) {
      return json(res, 200, { status: 'not_yet', message: 'Sunday mock ka syllabus aur strategy Friday ko unlock hogi.' });
    }
    const daysToSunday = (7 - localDay) % 7;
    const sundayDate = new Date(Date.UTC(year, month - 1, day + daysToSunday)).toISOString().slice(0, 10);
    const { data: existing } = await adm.from('mock_tests')
      .select('id,title,scheduled_for,strategy_text,duration_min,total_marks')
      .eq('assigned_user_id', me.uid).eq('exam_id', me.exam.id)
      .eq('scheduled_for', sundayDate).maybeSingle();
    if (existing) return json(res, 200, { status: 'existing', test: existing });

    const { data: progress, error: progressError } = await adm.from('student_syllabus_progress')
      .select('node_id').eq('user_id', me.uid).eq('completed', true).limit(2000);
    if (progressError) return json(res, 500, { error: 'Could not read your completed syllabus.' });
    const nodeIds = [...new Set((progress || []).map(x => x.node_id).filter(Boolean))];
    if (!nodeIds.length) return json(res, 200, { status: 'not_ready', message: 'Pehle Notes & Revision ya Today’s Plan mein apne completed topics tick karo. Sunday mock unhi topics se banega.' });

    const { data: pool, error: poolError } = await adm.from('questions')
      .select('id,node_id,body,options,correct_option,explanation')
      .eq('exam_id', me.exam.id).is('mock_test_id', null).in('node_id', nodeIds).limit(300);
    if (poolError) return json(res, 500, { error: 'Could not build your completed-syllabus question pool.' });
    const valid = (pool || []).filter(q => Array.isArray(q.options) && q.options.length >= 2 &&
      Number.isInteger(q.correct_option) && q.correct_option >= 0 && q.correct_option < q.options.length);
    if (valid.length < 5) {
      return json(res, 200, { status: 'not_ready', message: 'Tumhare completed syllabus se abhi 5 verified questions available nahi hain. Academic team PYQs upload karte hi mock unlock hoga.' });
    }
    for (let i = valid.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [valid[i], valid[j]] = [valid[j], valid[i]];
    }
    const selected = valid.slice(0, Math.min(20, valid.length));
    const { data: nodes } = await adm.from('syllabus_nodes')
      .select('id,title,level,parent_id').eq('exam_id', me.exam.id);
    const byId = Object.fromEntries((nodes || []).map(n => [n.id, n]));
    const completedTitles = nodeIds.map(id => {
      const topic = byId[id], chapter = topic && byId[topic.parent_id];
      return chapter ? chapter.title : (topic ? topic.title : '');
    }).filter(Boolean);
    const chapters = [...new Set(completedTitles)].slice(0, 10);
    const title = 'Sunday Diagnostic · ' + me.target_exam + ' · ' + sundayDate;
    const strategy = 'PrepX Ai weekly diagnostic pattern: ' + selected.length +
      ' MCQs · ' + (selected.length * 2) + ' minutes · 1 mark per correct answer · no negative marking. ' +
      'Syllabus sirf tumhare completed topics se: ' + chapters.join(', ') +
      '. Strategy: pehle easy questions solve karo, phir lengthy questions; last 5 minutes answers review karo. ' +
      'Ye personalised practice test hai, official full-length exam pattern nahi.';
    const { data: test, error: testError } = await adm.from('mock_tests').insert({
      exam_id: me.exam.id, exam: me.target_exam, assigned_user_id: me.uid,
      title, duration_min: selected.length * 2, total_marks: selected.length,
      negative_marks: 0, is_premium: true, published: false, is_active: true,
      scheduled_for: sundayDate, strategy_text: strategy, publish_at: new Date().toISOString()
    }).select().single();
    if (testError) return json(res, 500, { error: 'Could not create your Sunday mock.' });
    const questionRows = selected.map((q, index) => {
      const topic = byId[q.node_id], chapter = topic && byId[topic.parent_id];
      const subject = chapter && byId[chapter.parent_id];
      return {
        test_id: test.id, position: index + 1,
        subject: subject ? subject.title : 'General',
        topic: (chapter ? chapter.title + ' — ' : '') + (topic ? topic.title : 'Completed syllabus'),
        question: q.body, options: q.options, correct_index: q.correct_option,
        explanation: q.explanation || null, marks: 1
      };
    });
    const { error: insertError } = await adm.from('mock_questions').insert(questionRows);
    if (insertError) {
      await adm.from('mock_tests').delete().eq('id', test.id);
      return json(res, 500, { error: 'Sunday mock questions could not be saved.' });
    }
    return json(res, 200, { status: 'created', test: {
      id: test.id, title: test.title, scheduled_for: test.scheduled_for,
      strategy_text: test.strategy_text, duration_min: test.duration_min,
      total_marks: test.total_marks, exam: test.exam
    }});
  }

  if (body.action === 'list') {
    const columns = 'id, exam, title, duration_min, total_marks, negative_marks, scheduled_for, strategy_text, publish_at';
    const [published, assigned] = await Promise.all([
      adm.from('mock_tests').select(columns).eq('exam_id', me.exam.id).eq('exam', me.target_exam)
        .eq('published', true).eq('is_active', true).order('scheduled_for', { ascending: true, nullsFirst: false }).limit(100),
      adm.from('mock_tests').select(columns).eq('exam_id', me.exam.id).eq('exam', me.target_exam)
        .eq('assigned_user_id', me.uid).eq('published', false).eq('is_active', true).limit(20)
    ]);
    if (published.error || assigned.error) return json(res, 500, { error: 'Could not load tests.' });
    const data = [...(assigned.data || []), ...(published.data || [])];
    return json(res, 200, { tests: data });
  }

  if (body.action === 'start') {
    const testId = String(body.test_id || '');
    if (!/^[0-9a-f-]{36}$/i.test(testId)) return json(res, 400, { error: 'Invalid test.' });
    const { data: test } = await adm.from('mock_tests').select('*').eq('id', testId)
      .eq('exam_id', me.exam.id).eq('exam', me.target_exam).eq('is_active', true).maybeSingle();
    if (!test || (!test.published && test.assigned_user_id !== me.uid)) {
      return json(res, 404, { error: 'Test not found for your active exam, or it has not been published for you.' });
    }

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
