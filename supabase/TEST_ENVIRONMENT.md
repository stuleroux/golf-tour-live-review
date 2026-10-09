# Supabase Test Environment
Preferred local: Docker + `npx supabase start` then `npx supabase db reset`.
Hosted alternative: use a dedicated development project only. Never run destructive reset tests against production.
Required live RLS scenarios: organiser all writes; participant own match writes; participant other match denied; spectator read only; confirmed-match edits denied until reopen; duplicate client_event_id protected; cross-Tour relationships rejected.
