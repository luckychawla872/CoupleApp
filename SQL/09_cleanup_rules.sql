-- ============================================================================
-- Housekeeping and Cleanup Stored Procedures
-- ============================================================================

-- 1. Function to clean up expired pairing requests
CREATE OR REPLACE FUNCTION public.cleanup_expired_pairing_requests()
RETURNS void AS $$
BEGIN
    DELETE FROM public.pairing_requests
    WHERE expires_at < timezone('utc'::text, now());
END;
$$ LANGUAGE plpgsql;

-- 2. Function to handle 90-day inactivity account deletion
-- Accounts inactive for 90 days are flagged as 'pending_deletion'.
-- After another 7 days in 'pending_deletion' state (97 days total inactivity), 
-- they are permanently erased from auth.users (cascading to profiles/messages).
CREATE OR REPLACE FUNCTION public.process_inactive_accounts()
RETURNS void AS $$
BEGIN
    -- Step 1: Flag active profiles that have been inactive for more than 90 days
    UPDATE public.profiles
    SET status = 'pending_deletion'::account_status
    WHERE status = 'active'::account_status
      AND last_seen < timezone('utc'::text, now() - INTERVAL '90 days');

    -- Step 2: Delete auth.users accounts where the profile has been 'pending_deletion' for over 7 days
    -- This triggers ON DELETE CASCADE on public.profiles and deletes all associated user data
    DELETE FROM auth.users
    WHERE id IN (
        SELECT id FROM public.profiles
        WHERE status = 'pending_deletion'::account_status
          AND last_seen < timezone('utc'::text, now() - INTERVAL '97 days')
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HOW TO AUTOMATE CLEANUP TASKS IN SUPABASE (OPTIONAL)
-- ============================================================================
-- If you want to automate these cleanup functions, you can enable pg_cron in 
-- your Supabase database (via Database -> Extensions -> pg_cron).
--
-- Once enabled, run the following SQL commands to schedule them:
--
-- -- Schedule pairing request cleanup every 10 minutes
-- SELECT cron.schedule(
--   'cleanup-expired-pairing-requests',
--   '*/10 * * * *',
--   'SELECT public.cleanup_expired_pairing_requests();'
-- );
--
-- -- Schedule account deletion processing every day at midnight UTC
-- SELECT cron.schedule(
--   'process-inactive-accounts',
--   '0 0 * * *',
--   'SELECT public.process_inactive_accounts();'
-- );
