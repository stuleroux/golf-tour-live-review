-- Phase 4 server-side course import privileges.
--
-- The service_role performs the controlled data import.
-- No DELETE permission is required.
-- RLS remains unchanged for application users.

grant select, insert, update
on table public.courses
to service_role;

grant select, insert, update
on table public.course_tees
to service_role;

grant select, insert, update
on table public.course_holes
to service_role;
