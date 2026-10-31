-- Targeted indexes for the exam question, mock-attempt and PYQ query paths.
create index if not exists questions_exam_pyq_node_idx
  on public.questions(exam_id,is_pyq,node_id)
  where mock_test_id is null;

create index if not exists questions_mock_test_idx
  on public.questions(mock_test_id)
  where mock_test_id is not null;

create index if not exists mock_attempts_test_id_idx
  on public.mock_attempts(test_id);

create index if not exists pyq_attempts_question_id_idx
  on public.pyq_attempts(question_id);
