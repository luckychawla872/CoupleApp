-- ============================================================================
-- Row Level Security (RLS) Configuration for Couple Messenger
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pairing_requests ENABLE ROW LEVEL SECURITY;

-- Enable RLS on optional tables
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 1. Profiles Table Policies
-- ============================================================================

-- SELECT: Allow any authenticated user to select profiles.
-- (Required for username availability check, finding a partner by connection code, and looking up partner's display info/E2EE key).
CREATE POLICY "Allow public select on profiles" ON public.profiles
    FOR SELECT TO authenticated USING (true);

-- INSERT: Allow authenticated users to insert their own profile row during sign-up.
CREATE POLICY "Allow users to insert their own profile" ON public.profiles
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

-- UPDATE: Allow users to update their own profile OR allow conversation partners to update each other's profile verification status during dissolution.
CREATE POLICY "Allow profile updates for owner or partner" ON public.profiles
    FOR UPDATE TO authenticated
    USING (
        auth.uid() = id
        OR
        EXISTS (
            SELECT 1 FROM public.participants p1
            JOIN public.participants p2 ON p1.conversation_id = p2.conversation_id
            WHERE p1.profile_id = auth.uid() AND p2.profile_id = public.profiles.id
        )
    )
    WITH CHECK (
        auth.uid() = id
        OR
        EXISTS (
            SELECT 1 FROM public.participants p1
            JOIN public.participants p2 ON p1.conversation_id = p2.conversation_id
            WHERE p1.profile_id = auth.uid() AND p2.profile_id = public.profiles.id
        )
    );

-- ============================================================================
-- 2. Conversations Table Policies
-- ============================================================================

-- INSERT: Allow authenticated users to create a conversation.
CREATE POLICY "Allow insert conversations for authenticated users" ON public.conversations
    FOR INSERT TO authenticated WITH CHECK (true);

-- SELECT: Allow viewing conversations if the user is a participant OR if the conversation was just created and participant rows don't exist yet.
-- (Avoids the race condition of returning the newly created conversation before participants are inserted).
CREATE POLICY "Allow view conversations for participants" ON public.conversations
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = public.conversations.id AND profile_id = auth.uid()
        )
        OR
        NOT EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = public.conversations.id
        )
    );

-- UPDATE: Allow updating conversations (e.g. dissolution flags) if the user is a participant.
CREATE POLICY "Allow update conversations for participants" ON public.conversations
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = public.conversations.id AND profile_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = public.conversations.id AND profile_id = auth.uid()
        )
    );

-- ============================================================================
-- 3. Participants Table Policies
-- ============================================================================

-- INSERT: Allow authenticated users to add participants (joining a relationship).
CREATE POLICY "Allow insert participants" ON public.participants
    FOR INSERT TO authenticated WITH CHECK (true);

-- SELECT: Allow viewing participants in conversations you are a member of.
CREATE POLICY "Allow select participants" ON public.participants
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.participants p
            WHERE p.conversation_id = public.participants.conversation_id 
            AND p.profile_id = auth.uid()
        )
    );

-- DELETE: Allow participants to remove participant rows (unlinking/relationship dissolution).
CREATE POLICY "Allow delete participants" ON public.participants
    FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.participants p
            WHERE p.conversation_id = public.participants.conversation_id 
            AND p.profile_id = auth.uid()
        )
    );

-- ============================================================================
-- 4. Messages Table Policies
-- ============================================================================

-- SELECT: Allow reading messages if the user is a participant in the message's conversation.
CREATE POLICY "Allow select messages" ON public.messages
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = public.messages.conversation_id 
            AND profile_id = auth.uid()
        )
    );

-- INSERT: Allow sending messages to conversations the user is currently participating in.
CREATE POLICY "Allow insert messages" ON public.messages
    FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = public.messages.conversation_id 
            AND profile_id = auth.uid()
        )
    );

-- UPDATE: Allow updating messages (marking as read, editing text, or reaction payloads) for participants.
CREATE POLICY "Allow update messages" ON public.messages
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = public.messages.conversation_id 
            AND profile_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = public.messages.conversation_id 
            AND profile_id = auth.uid()
        )
    );

-- DELETE: Allow deleting messages inside the user's active conversation.
CREATE POLICY "Allow delete messages" ON public.messages
    FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.participants
            WHERE conversation_id = public.messages.conversation_id 
            AND profile_id = auth.uid()
        )
    );

-- ============================================================================
-- 5. Pairing Requests Table Policies
-- ============================================================================

-- SELECT: Allow any authenticated user to view pairing requests (needed to check if a code entered by a partner exists and is valid).
CREATE POLICY "Allow select pairing requests" ON public.pairing_requests
    FOR SELECT TO authenticated USING (true);

-- INSERT: Allow sending pairing requests where the sender is the current authenticated user.
CREATE POLICY "Allow insert pairing requests" ON public.pairing_requests
    FOR INSERT TO authenticated WITH CHECK (sender_id = auth.uid());

-- UPDATE: Allow updating pairing requests (e.g. setting receiver_id/status during linking) if user is sender or receiver.
CREATE POLICY "Allow update pairing requests" ON public.pairing_requests
    FOR UPDATE TO authenticated
    USING (sender_id = auth.uid() OR receiver_id = auth.uid() OR receiver_id IS NULL)
    WITH CHECK (sender_id = auth.uid() OR receiver_id = auth.uid());

-- DELETE: Allow deleting pairing requests when pairing is completed or cancelled.
CREATE POLICY "Allow delete pairing requests" ON public.pairing_requests
    FOR DELETE TO authenticated
    USING (sender_id = auth.uid() OR receiver_id = auth.uid());


-- ============================================================================
-- 6. Optional Tables Policies (Security by Default)
-- ============================================================================

CREATE POLICY "Allow owner select user_settings" ON public.user_settings
    FOR SELECT TO authenticated USING (profile_id = auth.uid());
CREATE POLICY "Allow owner update user_settings" ON public.user_settings
    FOR ALL TO authenticated USING (profile_id = auth.uid()) WITH CHECK (profile_id = auth.uid());

CREATE POLICY "Allow owner select devices" ON public.devices
    FOR SELECT TO authenticated USING (profile_id = auth.uid());
CREATE POLICY "Allow owner all devices" ON public.devices
    FOR ALL TO authenticated USING (profile_id = auth.uid()) WITH CHECK (profile_id = auth.uid());

CREATE POLICY "Allow owner select sessions" ON public.sessions
    FOR SELECT TO authenticated USING (profile_id = auth.uid());
CREATE POLICY "Allow owner all sessions" ON public.sessions
    FOR ALL TO authenticated USING (profile_id = auth.uid()) WITH CHECK (profile_id = auth.uid());

CREATE POLICY "Allow recipient notifications" ON public.notifications
    FOR ALL TO authenticated USING (recipient_id = auth.uid()) WITH CHECK (recipient_id = auth.uid());

CREATE POLICY "Allow select attachments" ON public.attachments
    FOR SELECT TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.messages m
            JOIN public.participants p ON m.conversation_id = p.conversation_id
            WHERE m.id = public.attachments.message_id AND p.profile_id = auth.uid()
        )
    );
CREATE POLICY "Allow insert attachments" ON public.attachments
    FOR INSERT TO authenticated WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.messages m
            JOIN public.participants p ON m.conversation_id = p.conversation_id
            WHERE m.id = public.attachments.message_id AND p.profile_id = auth.uid()
        )
    );

CREATE POLICY "Allow select reactions" ON public.message_reactions
    FOR SELECT TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.messages m
            JOIN public.participants p ON m.conversation_id = p.conversation_id
            WHERE m.id = public.message_reactions.message_id AND p.profile_id = auth.uid()
        )
    );
CREATE POLICY "Allow insert reactions" ON public.message_reactions
    FOR INSERT TO authenticated WITH CHECK (
        profile_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.messages m
            JOIN public.participants p ON m.conversation_id = p.conversation_id
            WHERE m.id = public.message_reactions.message_id AND p.profile_id = auth.uid()
        )
    );
