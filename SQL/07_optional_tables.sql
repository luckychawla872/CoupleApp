-- ============================================================================
-- NOTE: The following tables are part of the original Product Requirements Document (PRD)
-- specifications but are NOT currently queried or modified in the current Flutter frontend implementation.
-- They are provided here for completeness and future features.
-- ============================================================================

-- 6. Optional: Message Reactions Table (App currently uses E2EE reactions in the messages table directly)
CREATE TABLE public.message_reactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE NOT NULL,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    reaction_emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(message_id, profile_id)
);

-- 7. Optional: Attachments Table (App currently uses ImageKit for media URLs stored inside E2EE message payloads)
CREATE TABLE public.attachments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE NOT NULL,
    encrypted_url TEXT NOT NULL,         
    thumbnail_url TEXT,                 
    mime_type VARCHAR(50) NOT NULL,
    file_size INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. Optional: Devices Table (For E2EE key distribution and push notification tokens)
CREATE TABLE public.devices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    device_token TEXT UNIQUE NOT NULL,
    platform device_platform NOT NULL,
    public_identity_key TEXT NOT NULL,  
    is_trusted BOOLEAN DEFAULT false NOT NULL,
    last_active TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 9. Optional: Sessions Table (No IP address stored to preserve privacy)
CREATE TABLE public.sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    country VARCHAR(100),
    device_name VARCHAR(100) NOT NULL,
    user_agent TEXT NOT NULL,
    logged_in_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    last_active TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    token_version INT DEFAULT 1 NOT NULL
);

-- 10. Optional: Notifications Table (For push notification queueing)
CREATE TABLE public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    recipient_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 11. Optional: User Settings Table (Local settings are currently stored on device storage)
CREATE TABLE public.user_settings (
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE PRIMARY KEY,
    theme_preference VARCHAR(15) DEFAULT 'system' NOT NULL,
    notifications_enabled BOOLEAN DEFAULT true NOT NULL,
    silent_mode_enabled BOOLEAN DEFAULT false NOT NULL,
    last_modified_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
