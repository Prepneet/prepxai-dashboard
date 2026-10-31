-- Add currently missing paper sections for SSC CGL, IBPS/SBI and Bihar Police.
-- All additions remain in needs_review until matched to the exact current notification.
do $$
declare
  d jsonb; subj jsonb; chap jsonb; topic text;
  exam_uuid uuid; subject_uuid uuid; chapter_uuid uuid;
  s_order integer; c_order integer; t_order integer;
begin
  for d in select value from jsonb_array_elements($data$[
    {"slug":"ssc-cgl","subjects":[{"subject":"Computer Knowledge (Tier-II)","chapters":[
      {"title":"Computer Fundamentals","topics":["Characteristics and generations of computers","Input, output and storage devices","Memory units, primary memory and secondary storage"]},
      {"title":"Hardware, Software and Operating Systems","topics":["CPU, motherboard and peripheral devices","System software, application software and utility programs","Operating system functions, files and folders"]},
      {"title":"Office and Productivity Tools","topics":["Word processing and document formatting","Spreadsheets, formulas, charts and cell references","Presentation software and slide tools"]},
      {"title":"Internet, Networking and E-mail","topics":["Internet, intranet, web browsers and search engines","LAN, WAN, network devices and basic protocols","E-mail, attachments, cloud storage and online collaboration"]},
      {"title":"Cyber Security and Digital Literacy","topics":["Malware, phishing, passwords and authentication","Safe browsing, privacy and data protection","Digital payments, online safety and cyber hygiene"]}
    ]}]},
    {"slug":"ibps-sbi-banking","subjects":[{"subject":"Computer Aptitude","chapters":[
      {"title":"Computer Fundamentals and Architecture","topics":["Computer generations, characteristics and applications","CPU, input/output devices and memory hierarchy","Number systems, binary arithmetic and data representation"]},
      {"title":"Software and Operating Systems","topics":["System and application software","Operating system functions and file management","Common office productivity applications"]},
      {"title":"Internet and Networking","topics":["Internet, intranet, browsers and search engines","LAN, WAN, network topologies and devices","E-mail, cloud services and digital communication"]},
      {"title":"Cyber Security and Digital Banking","topics":["Malware, phishing, social engineering and safe authentication","Encryption, firewalls, antivirus and data privacy","UPI, cards, net banking, mobile banking and payment security"]}
    ]}]},
    {"slug":"bihar-police","subjects":[
      {"subject":"English","chapters":[
        {"title":"Grammar and Usage","topics":["Parts of speech, articles and prepositions","Tenses, subject–verb agreement and sentence structure","Voice, narration and punctuation"]},
        {"title":"Vocabulary and Comprehension","topics":["Synonyms, antonyms and word meanings","Idioms, phrases and one-word substitutions","Reading comprehension and sentence correction"]}
      ]},
      {"subject":"Social Science","chapters":[
        {"title":"History","topics":["Ancient and medieval Indian history","Modern Indian history and the freedom movement","Bihar history, culture and important personalities"]},
        {"title":"Geography","topics":["Physical geography of India and Bihar","Rivers, climate, soil, agriculture and natural resources","Population, transport and economic geography"]},
        {"title":"Civics and Constitution","topics":["Indian Constitution and fundamental rights/duties","Parliament, state legislature, executive and judiciary","Local self-government and democratic institutions"]},
        {"title":"Economics","topics":["Basic economic concepts and sectors","Indian economy, poverty, unemployment and development","Bihar economy, agriculture and public welfare schemes"]}
      ]}
    ]}
  ]$data$::jsonb) loop
    select id into exam_uuid from public.exams where slug=d->>'slug';
    s_order:=100;
    for subj in select value from jsonb_array_elements(d->'subjects') loop
      select id into subject_uuid from public.syllabus_nodes where exam_id=exam_uuid and level='subject' and title=subj->>'subject' limit 1;
      if subject_uuid is null then
        insert into public.syllabus_nodes(exam_id,parent_id,title,level,sort_order) values(exam_uuid,null,subj->>'subject','subject',s_order) returning id into subject_uuid;
      end if;
      c_order:=0;
      for chap in select value from jsonb_array_elements(subj->'chapters') loop
        c_order:=c_order+1;
        select id into chapter_uuid from public.syllabus_nodes where exam_id=exam_uuid and level='chapter' and parent_id=subject_uuid and title=chap->>'title' limit 1;
        if chapter_uuid is null then
          insert into public.syllabus_nodes(exam_id,parent_id,title,level,sort_order) values(exam_uuid,subject_uuid,chap->>'title','chapter',c_order) returning id into chapter_uuid;
        end if;
        t_order:=0;
        for topic in select jsonb_array_elements_text(chap->'topics') loop
          t_order:=t_order+1;
          if not exists(select 1 from public.syllabus_nodes where exam_id=exam_uuid and level='topic' and parent_id=chapter_uuid and title=topic) then
            insert into public.syllabus_nodes(exam_id,parent_id,title,level,sort_order) values(exam_uuid,chapter_uuid,topic,'topic',t_order);
          end if;
        end loop;
      end loop;
    end loop;
  end loop;
end $$;

insert into public.syllabus_topic_audit(topic_id,exam_id,review_status,review_note,source_title,source_url,syllabus_year,updated_at)
select n.id,n.exam_id,'needs_review',
  'Additional paper section added from the latest located exam framework; verify the exact current notification before certification.',
  case e.slug when 'ssc-cgl' then 'SSC CGL 2026 official notification' when 'ibps-sbi-banking' then 'IBPS PO/MT XVI 2026 official notification' else 'CSBC Bihar Police recruitment syllabus portal' end,
  case e.slug when 'ssc-cgl' then 'https://ssc.gov.in/api/attachment/uploads/masterData/NoticeBoards/Notice_of_adv_cgl_2026.pdf'
    when 'ibps-sbi-banking' then 'https://www.ibps.in/index.php/management-trainees-xvi/' else 'https://csbc.bihar.gov.in/Syllabus.htm' end,
  case e.slug when 'ssc-cgl' then 2026 when 'ibps-sbi-banking' then 2026 else 2025 end,now()
from public.syllabus_nodes n join public.exams e on e.id=n.exam_id
where n.level='topic' and (
  (e.slug='ssc-cgl' and n.parent_id in (select c.id from public.syllabus_nodes c join public.syllabus_nodes s on s.id=c.parent_id where s.title='Computer Knowledge (Tier-II)')) or
  (e.slug='ibps-sbi-banking' and n.parent_id in (select c.id from public.syllabus_nodes c join public.syllabus_nodes s on s.id=c.parent_id where s.title='Computer Aptitude')) or
  (e.slug='bihar-police' and n.parent_id in (select c.id from public.syllabus_nodes c join public.syllabus_nodes s on s.id=c.parent_id where s.title in ('English','Social Science')))
)
on conflict(topic_id) do update set source_title=excluded.source_title,source_url=excluded.source_url,syllabus_year=excluded.syllabus_year,updated_at=now();
