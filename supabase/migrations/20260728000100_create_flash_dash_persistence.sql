-- Flash Dash persistence
--
-- Schema assumptions that must be confirmed before applying:
--   public.users(id uuid, class_id uuid, role text)
--   public.classes(id uuid, teacher_id uuid)
--   public.word_lists(id uuid)
--   public.words(id uuid, list_id uuid)
--   public.users.id matches auth.users.id for authenticated app users.

begin;

create schema if not exists private;
revoke all on schema private from public;

create table public.flash_dash_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  list_id uuid not null,
  started_at timestamptz not null,
  completed_at timestamptz,
  duration_ms bigint not null,
  word_count integer not null,
  total_attempts integer not null,
  first_try_known integer not null,
  completed boolean not null,
  created_at timestamptz not null default now(),

  constraint flash_dash_sessions_user_fk
    foreign key (user_id)
    references public.users(id)
    on delete cascade,

  constraint flash_dash_sessions_list_fk
    foreign key (list_id)
    references public.word_lists(id)
    on delete restrict,

  constraint flash_dash_sessions_id_user_unique
    unique (id, user_id),

  constraint flash_dash_sessions_duration_nonnegative
    check (duration_ms >= 0),

  constraint flash_dash_sessions_word_count_positive
    check (word_count > 0),

  constraint flash_dash_sessions_attempt_count_nonnegative
    check (total_attempts >= 0),

  constraint flash_dash_sessions_first_try_range
    check (first_try_known >= 0 and first_try_known <= word_count),

  constraint flash_dash_sessions_timestamp_order
    check (completed_at is null or completed_at >= started_at),

  constraint flash_dash_sessions_completion_shape
    check (
      (completed = true and completed_at is not null)
      or
      (completed = false and completed_at is null)
    ),

  constraint flash_dash_sessions_completed_attempt_minimum
    check (completed = false or total_attempts >= word_count)
);

create table public.flash_dash_attempts (
  id bigint generated always as identity primary key,
  session_id uuid not null,
  user_id uuid not null,
  word_id uuid not null,
  sequence_number integer not null,
  result text not null,
  elapsed_ms bigint not null,
  created_at timestamptz not null default now(),

  constraint flash_dash_attempts_session_user_fk
    foreign key (session_id, user_id)
    references public.flash_dash_sessions(id, user_id)
    on delete cascade,

  constraint flash_dash_attempts_user_fk
    foreign key (user_id)
    references public.users(id)
    on delete cascade,

  constraint flash_dash_attempts_word_fk
    foreign key (word_id)
    references public.words(id)
    on delete restrict,

  constraint flash_dash_attempts_session_sequence_unique
    unique (session_id, sequence_number),

  constraint flash_dash_attempts_sequence_positive
    check (sequence_number > 0),

  constraint flash_dash_attempts_elapsed_nonnegative
    check (elapsed_ms >= 0),

  constraint flash_dash_attempts_result_valid
    check (result in ('known', 'practice_again', 'timeout'))
);

create index flash_dash_sessions_user_started_idx
  on public.flash_dash_sessions (user_id, started_at desc);

create index flash_dash_sessions_list_started_idx
  on public.flash_dash_sessions (list_id, started_at desc);

create index flash_dash_attempts_user_created_idx
  on public.flash_dash_attempts (user_id, created_at desc);

create index flash_dash_attempts_word_result_idx
  on public.flash_dash_attempts (word_id, result);

-- The unique constraint already provides an index for
-- (session_id, sequence_number), so no duplicate index is created.

create or replace function private.is_teacher_of_student(p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.users as student
    join public.classes as classroom
      on classroom.id = student.class_id
    where student.id = p_student_id
      and classroom.teacher_id = (select auth.uid())
  );
$$;

revoke all on function private.is_teacher_of_student(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_teacher_of_student(uuid) to authenticated;

create or replace function private.is_student_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.users as user_row
    where user_row.id = p_user_id
      and user_row.role = 'student'
  );
$$;

revoke all on function private.is_student_user(uuid) from public;
grant execute on function private.is_student_user(uuid) to authenticated;

-- Defense-in-depth validation for direct attempt inserts as well as RPC writes.
create or replace function private.validate_flash_dash_attempt_word()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_list_id uuid;
begin
  select session_row.list_id
    into v_list_id
  from public.flash_dash_sessions as session_row
  where session_row.id = new.session_id
    and session_row.user_id = new.user_id;

  if v_list_id is null then
    raise exception 'Flash Dash session does not exist for this user.'
      using errcode = '23503';
  end if;

  if not exists (
    select 1
    from public.words as word_row
    where word_row.id = new.word_id
      and word_row.list_id = v_list_id
  ) then
    raise exception 'Flash Dash attempt word does not belong to the session list.'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_flash_dash_attempt_word() from public;

create trigger validate_flash_dash_attempt_word_before_insert
before insert on public.flash_dash_attempts
for each row
execute function private.validate_flash_dash_attempt_word();

alter table public.flash_dash_sessions enable row level security;
alter table public.flash_dash_attempts enable row level security;

-- No access is granted to anon. Authenticated users get only the operations
-- required by this feature; no UPDATE or DELETE privilege is granted.
revoke all on public.flash_dash_sessions from anon, authenticated;
revoke all on public.flash_dash_attempts from anon, authenticated;

grant select, insert on public.flash_dash_sessions to authenticated;
grant select, insert on public.flash_dash_attempts to authenticated;
grant usage, select on sequence public.flash_dash_attempts_id_seq to authenticated;

create policy "Students insert their own Flash Dash sessions"
on public.flash_dash_sessions
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and private.is_student_user(user_id)
);

create policy "Students and their teacher read Flash Dash sessions"
on public.flash_dash_sessions
for select
to authenticated
using (
  (select auth.uid()) = user_id
  or private.is_teacher_of_student(user_id)
);

create policy "Students insert attempts for their own Flash Dash sessions"
on public.flash_dash_attempts
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and private.is_student_user(user_id)
  and exists (
    select 1
    from public.flash_dash_sessions as session_row
    where session_row.id = session_id
      and session_row.user_id = (select auth.uid())
  )
);

create policy "Students and their teacher read Flash Dash attempts"
on public.flash_dash_attempts
for select
to authenticated
using (
  (select auth.uid()) = user_id
  or private.is_teacher_of_student(user_id)
);

-- Save one complete session and all attempt rows in one database transaction.
-- The client supplies a UUID so a retry after a lost HTTP response is idempotent.
create or replace function public.save_flash_dash_session(
  p_session_id uuid,
  p_list_id uuid,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_duration_ms bigint,
  p_word_count integer,
  p_total_attempts integer,
  p_first_try_known integer,
  p_completed boolean,
  p_attempts jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing public.flash_dash_sessions%rowtype;
  v_payload_count bigint;
  v_distinct_sequence_count bigint;
  v_min_sequence integer;
  v_max_sequence integer;
  v_distinct_word_count bigint;
  v_known_word_count bigint;
  v_first_try_known bigint;
  v_invalid_payload_count bigint;
  v_payload_differs boolean;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to save Flash Dash.'
      using errcode = '42501';
  end if;

  if not private.is_student_user(v_user_id) then
    raise exception 'Only student accounts may save Flash Dash sessions.'
      using errcode = '42501';
  end if;

  if p_session_id is null or p_list_id is null then
    raise exception 'Session id and list id are required.'
      using errcode = '22023';
  end if;

  if p_completed is null
     or p_duration_ms is null
     or p_word_count is null
     or p_total_attempts is null
     or p_first_try_known is null then
    raise exception 'Flash Dash aggregate values are required.'
      using errcode = '22023';
  end if;

  if p_started_at is null then
    raise exception 'started_at is required.' using errcode = '22023';
  end if;

  if p_completed and p_completed_at is null then
    raise exception 'A completed session requires completed_at.'
      using errcode = '22023';
  end if;

  if not p_completed and p_completed_at is not null then
    raise exception 'An incomplete session cannot have completed_at.'
      using errcode = '22023';
  end if;

  if p_completed_at is not null and p_completed_at < p_started_at then
    raise exception 'completed_at cannot be before started_at.'
      using errcode = '22023';
  end if;

  if p_duration_ms < 0
     or p_word_count <= 0
     or p_total_attempts < 0
     or p_first_try_known < 0
     or p_first_try_known > p_word_count then
    raise exception 'Invalid Flash Dash aggregate values.'
      using errcode = '22023';
  end if;

  if p_attempts is null or jsonb_typeof(p_attempts) <> 'array' then
    raise exception 'p_attempts must be a JSON array.'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.word_lists as list_row
    where list_row.id = p_list_id
  ) then
    raise exception 'The Flash Dash word list does not exist.'
      using errcode = '23503';
  end if;

  select
    count(*),
    count(distinct payload.sequence_number),
    min(payload.sequence_number),
    max(payload.sequence_number),
    count(distinct payload.word_id),
    count(*) filter (
      where payload.word_id is null
         or payload.sequence_number is null
         or payload.result is null
         or payload.elapsed_ms is null
         or payload.sequence_number <= 0
         or payload.elapsed_ms < 0
         or payload.result not in ('known', 'practice_again', 'timeout')
    )
  into
    v_payload_count,
    v_distinct_sequence_count,
    v_min_sequence,
    v_max_sequence,
    v_distinct_word_count,
    v_invalid_payload_count
  from jsonb_to_recordset(p_attempts) as payload(
    word_id uuid,
    sequence_number integer,
    result text,
    elapsed_ms bigint
  );

  if v_payload_count <> p_total_attempts then
    raise exception 'Attempt payload count does not match total_attempts.'
      using errcode = '22023';
  end if;

  if v_invalid_payload_count > 0 then
    raise exception 'Attempt payload contains invalid values.'
      using errcode = '22023';
  end if;

  if p_total_attempts > 0 and (
    v_distinct_sequence_count <> p_total_attempts
    or v_min_sequence <> 1
    or v_max_sequence <> p_total_attempts
  ) then
    raise exception 'Attempt sequence numbers must be contiguous from 1.'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_attempts) as payload(
      word_id uuid,
      sequence_number integer,
      result text,
      elapsed_ms bigint
    )
    left join public.words as word_row
      on word_row.id = payload.word_id
    where word_row.id is null
       or word_row.list_id <> p_list_id
  ) then
    raise exception 'Every attempt word must belong to the session list.'
      using errcode = '23514';
  end if;

  if exists (
    select payload.word_id
    from jsonb_to_recordset(p_attempts) as payload(
      word_id uuid,
      sequence_number integer,
      result text,
      elapsed_ms bigint
    )
    where payload.result = 'known'
    group by payload.word_id
    having count(*) > 1
  ) then
    raise exception 'A word can be cleared as known only once per session.'
      using errcode = '23514';
  end if;

  with parsed as (
    select *
    from jsonb_to_recordset(p_attempts) as payload(
      word_id uuid,
      sequence_number integer,
      result text,
      elapsed_ms bigint
    )
  ),
  first_results as (
    select distinct on (word_id)
      word_id,
      result
    from parsed
    order by word_id, sequence_number
  )
  select count(*) filter (where result = 'known')
    into v_first_try_known
  from first_results;

  if v_first_try_known <> p_first_try_known then
    raise exception 'first_try_known does not match the attempt payload.'
      using errcode = '23514';
  end if;

  select count(distinct payload.word_id) filter (
    where payload.result = 'known'
  )
    into v_known_word_count
  from jsonb_to_recordset(p_attempts) as payload(
    word_id uuid,
    sequence_number integer,
    result text,
    elapsed_ms bigint
  );

  if p_completed and (
    p_total_attempts < p_word_count
    or v_distinct_word_count <> p_word_count
    or v_known_word_count <> p_word_count
  ) then
    raise exception 'A completed session must clear every selected word.'
      using errcode = '23514';
  end if;

  -- Serialize retries that use the same client-generated session UUID. This
  -- closes the small race where two identical requests arrive concurrently.
  perform pg_advisory_xact_lock(
    hashtextextended(p_session_id::text, 0)
  );

  -- Idempotent retry path: an earlier request may have committed even if the
  -- client did not receive its HTTP response.
  select *
    into v_existing
  from public.flash_dash_sessions
  where id = p_session_id
  for update;

  if found then
    if v_existing.user_id <> v_user_id then
      raise exception 'This session id belongs to another user.'
        using errcode = '42501';
    end if;

    if v_existing.list_id is distinct from p_list_id
       or v_existing.started_at is distinct from p_started_at
       or v_existing.completed_at is distinct from p_completed_at
       or v_existing.duration_ms is distinct from p_duration_ms
       or v_existing.word_count is distinct from p_word_count
       or v_existing.total_attempts is distinct from p_total_attempts
       or v_existing.first_try_known is distinct from p_first_try_known
       or v_existing.completed is distinct from p_completed then
      raise exception 'Session id was reused with a different session payload.'
        using errcode = '23505';
    end if;

    with payload as (
      select *
      from jsonb_to_recordset(p_attempts) as item(
        word_id uuid,
        sequence_number integer,
        result text,
        elapsed_ms bigint
      )
    ),
    stored as (
      select word_id, sequence_number, result, elapsed_ms
      from public.flash_dash_attempts
      where session_id = p_session_id
    )
    select exists (
      select 1
      from payload
      full join stored using (sequence_number)
      where payload.word_id is distinct from stored.word_id
         or payload.result is distinct from stored.result
         or payload.elapsed_ms is distinct from stored.elapsed_ms
    )
    into v_payload_differs;

    if v_payload_differs then
      raise exception 'Session id was reused with different attempt data.'
        using errcode = '23505';
    end if;

    return p_session_id;
  end if;

  insert into public.flash_dash_sessions (
    id,
    user_id,
    list_id,
    started_at,
    completed_at,
    duration_ms,
    word_count,
    total_attempts,
    first_try_known,
    completed
  ) values (
    p_session_id,
    v_user_id,
    p_list_id,
    p_started_at,
    p_completed_at,
    p_duration_ms,
    p_word_count,
    p_total_attempts,
    p_first_try_known,
    p_completed
  );

  insert into public.flash_dash_attempts (
    session_id,
    user_id,
    word_id,
    sequence_number,
    result,
    elapsed_ms
  )
  select
    p_session_id,
    v_user_id,
    payload.word_id,
    payload.sequence_number,
    payload.result,
    payload.elapsed_ms
  from jsonb_to_recordset(p_attempts) as payload(
    word_id uuid,
    sequence_number integer,
    result text,
    elapsed_ms bigint
  )
  order by payload.sequence_number;

  return p_session_id;
end;
$$;

revoke all on function public.save_flash_dash_session(
  uuid,
  uuid,
  timestamptz,
  timestamptz,
  bigint,
  integer,
  integer,
  integer,
  boolean,
  jsonb
) from public, anon;

grant execute on function public.save_flash_dash_session(
  uuid,
  uuid,
  timestamptz,
  timestamptz,
  bigint,
  integer,
  integer,
  integer,
  boolean,
  jsonb
) to authenticated;

comment on table public.flash_dash_sessions is
  'One Flash Dash round. Kept separate from pronunciation attempts.';

comment on table public.flash_dash_attempts is
  'Ordered per-card outcomes for a Flash Dash session.';

comment on function public.save_flash_dash_session(
  uuid,
  uuid,
  timestamptz,
  timestamptz,
  bigint,
  integer,
  integer,
  integer,
  boolean,
  jsonb
) is
  'Atomically and idempotently stores one Flash Dash session and its attempts for auth.uid().';

commit;
