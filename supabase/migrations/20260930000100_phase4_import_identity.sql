-- Stable source identities make Phase 4 imports idempotent.
alter table public.courses add column if not exists source_course_id text;
create unique index if not exists courses_source_course_id_uq on public.courses(source_course_id) where source_course_id is not null;

-- Phase 4 source metadata retained on hole rows for future enrichment/reconciliation.
alter table public.course_holes add column if not exists source_url text;
alter table public.course_holes add column if not exists source_type text;
alter table public.course_holes add column if not exists confidence text;
