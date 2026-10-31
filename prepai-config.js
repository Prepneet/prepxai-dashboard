/*
 * Prep Ai shared config
 * status: 'official'  = confirmed by the conducting body (source noted)
 *         'tentative' = announced window / expected date, may change
 *         'estimated' = no announced date yet; based on past pattern. Update when notified.
 * Update dates from the admin panel later; keep this file as the single source.
 */
(function () {
  'use strict';

  var EXAMS = [
    {
      key: 'BPSC', label: 'BPSC (Bihar PSC)', icon: '🪷', sub: 'Bihar Civil Services', factor: 1,
      calendar: {
        2027: { date: '2027-03-15', status: 'tentative', note: 'BPSC 2027 prelims window expected. Always check the latest BPSC notification.' }
      }
    },
    {
      key: 'Railways (RRB)', label: 'Railways (RRB)', icon: '🚆', sub: 'NTPC, ALP, Group D', factor: 0,
      calendar: {
        2027: { date: '2027-06-15', status: 'estimated', note: 'RRB 2027 CEN abhi notify nahi hua. Graduate CEN 06/2026 ka CBT Dec 2026 mein expected hai.' }
      }
    },
    {
      key: 'Bihar Police', label: 'Bihar Police', icon: '🚔', sub: 'Constable recruitment', factor: 0,
      calendar: {}
    },
    {
      key: 'JEE Main', label: 'JEE Main', icon: '⚙️', sub: 'Engineering Entrance', factor: 1,
      calendar: {
        2027: { date: '2027-01-22', status: 'official', note: 'NTA exam calendar (16 Sep 2026): Session 1 22–30 Jan 2027. Session 2 (April 2027) ki date alag se aayegi.' }
      }
    },
    {
      key: 'JEE Advanced', label: 'JEE Advanced', icon: '🔬', sub: 'IIT Admissions', factor: 1.5,
      calendar: {
        2027: { date: '2027-05-24', status: 'estimated', note: 'JEE Advanced 2027 ki official date abhi announce nahi hui.' }
      }
    },
    {
      key: 'NEET UG', label: 'NEET UG', icon: '🩺', sub: 'Medical (MBBS / BDS)', factor: 1,
      calendar: {
        2027: { date: '2027-05-02', status: 'tentative', note: 'NTA ki official notice abhi nahi. Sources 2–3 May 2027 bata rahe hain. Registration Feb–Mar 2027 expected.' }
      }
    },
    {
      key: 'CUET UG', label: 'CUET UG', icon: '🏛️', sub: 'Central Universities', factor: 0.5,
      calendar: {
        2027: { date: '2027-05-15', status: 'estimated', note: 'CUET UG 2027 ki NTA date abhi official nahi.' }
      }
    },
    {
      key: 'SSC Exams', label: 'SSC (CGL / CHSL / GD)', icon: '📋', sub: 'CGL, CHSL, GD', factor: 0,
      calendar: {
        2027: { date: '2027-02-15', status: 'tentative', note: 'SSC calendar 2026-27: GD Constable Jan–Mar 2027. CGL aur CHSL 2027 ki date notify hone par update hogi.' }
      }
    },
    {
      key: 'UPSC CSE', label: 'UPSC Civil Services', icon: '🇮🇳', sub: 'Civil Services / IAS', factor: 1.5,
      calendar: {
        2027: { date: '2027-05-23', status: 'official', note: 'UPSC annual calendar 2027: Prelims 23 May 2027, notification 13 Jan 2027, Mains 20 Aug 2027.' }
      }
    },
    {
      key: 'NDA', label: 'NDA', icon: '🛡️', sub: 'National Defence Academy', factor: 0.5,
      calendar: {
        2027: { date: '2027-04-11', status: 'official', note: 'UPSC calendar 2027: NDA & NA (I) exam 11 Apr 2027. Cycle II: 19 Sep 2027.' }
      }
    },
    {
      key: 'CDS', label: 'CDS', icon: '🎖️', sub: 'Combined Defence Services', factor: 0.5,
      calendar: {
        2027: { date: '2027-04-11', status: 'official', note: 'UPSC calendar 2027: CDS (I) exam 11 Apr 2027. Cycle II: 19 Sep 2027.' }
      }
    },
    {
      key: 'Banking Exams', label: 'Banking (IBPS / SBI)', icon: '🏦', sub: 'IBPS PO, SBI PO / Clerk', factor: 0,
      calendar: {
        2027: { date: '2027-08-22', status: 'estimated', note: 'IBPS PO 2027 prelims Aug–Sep 2027 expected. SBI PO 2027 prelims Nov 2027 expected. ibps.in aur sbi.co.in par verify karein.' }
      }
    }
  ];

  function parseISO(s) {
    var p = s.split('-');
    return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
  }

  function todayLocal() {
    var d = new Date();
    return new Date(d.getFullYear(), d.getMonth(), d.getDate());
  }

  // Signup slugs saved by the landing page (lowercase) mapped to canonical keys.
  var ALIASES = {
    'neet': 'NEET UG', 'neet ug': 'NEET UG', 'neet-ug': 'NEET UG',
    'jee': 'JEE Main', 'jee main': 'JEE Main', 'jee-main': 'JEE Main', 'jee mains': 'JEE Main',
    'jee advanced': 'JEE Advanced', 'jee-advanced': 'JEE Advanced',
    'upsc': 'UPSC CSE', 'upsc cse': 'UPSC CSE', 'upsc-cse': 'UPSC CSE', 'ias': 'UPSC CSE',
    'cuet': 'CUET UG', 'cuet ug': 'CUET UG', 'cuet-ug': 'CUET UG',
    'ssc': 'SSC Exams', 'ssc exams': 'SSC Exams', 'ssc cgl': 'SSC Exams', 'ssc-cgl': 'SSC Exams',
    'rrb': 'Railways (RRB)', 'railways': 'Railways (RRB)', 'railway': 'Railways (RRB)',
    'nda': 'NDA', 'cds': 'CDS', 'nda-cds': 'NDA', 'nda / cds': 'NDA',
    'banking': 'Banking Exams', 'ibps': 'Banking Exams', 'sbi': 'Banking Exams', 'bank': 'Banking Exams',
    'jeem': 'JEE Main', 'jeea': 'JEE Advanced',
    'bpsc': 'BPSC'
  };

  function findExam(key) {
    if (!key) return null;
    var k = String(key).trim();
    for (var i = 0; i < EXAMS.length; i++) if (EXAMS[i].key === k) return EXAMS[i];
    var alias = ALIASES[k.toLowerCase()];
    if (alias && alias !== k) return findExam(alias);
    return null;
  }

  // Maps stage text saved at signup to 'beginner' | 'midway' | 'advanced' | ''.
  function normalizeStage(s) {
    var t = String(s || '').toLowerCase();
    if (/beginner|just starting|0-30/.test(t)) return 'beginner';
    if (/midway|mid|31-|40-|50-|60-/.test(t)) return 'midway';
    if (/advanced|revision|70|80|90/.test(t)) return 'advanced';
    return '';
  }

  // Returns { date:'YYYY-MM-DD', status, note }. Years without data are estimated from the previous year.
  function examDateFor(key, year) {
    var ex = findExam(key);
    if (!ex) return null;
    if (ex.calendar[year]) return ex.calendar[year];
    var prev = ex.calendar[year - 1];
    if (!prev) return null;
    var d = parseISO(prev.date);
    d.setFullYear(d.getFullYear() + 1);
    var iso = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
    return { date: iso, status: 'estimated', note: 'Pichle saal ke pattern par estimate. Official date aane par update hogi.' };
  }

  function daysLeft(iso) {
    return Math.round((parseISO(iso) - todayLocal()) / 86400000);
  }

  // Realistic daily hours by days left, syllabus stage and exam load. Capped at 14h.
  function recommendHours(key, stage, days) {
    var ex = findExam(key);
    var factor = ex ? ex.factor : 0;
    var base = days >= 365 ? 4 : days >= 270 ? 5 : days >= 180 ? 6.5 : days >= 120 ? 8 : days >= 60 ? 10 : days >= 30 ? 11.5 : 12;
    var stageAdd = { beginner: 1.5, midway: 0.5, advanced: 0 }[stage] || 0;
    var total = base + stageAdd + factor;
    total = Math.min(14, Math.max(3, Math.round(total * 2) / 2));
    return { mid: total, low: Math.max(3, total - 1), high: Math.min(14, total + 1) };
  }

  window.PREP = {
    EXAMS: EXAMS,
    findExam: findExam,
    normalizeStage: normalizeStage,
    examDateFor: examDateFor,
    daysLeft: daysLeft,
    recommendHours: recommendHours
  };
})();
