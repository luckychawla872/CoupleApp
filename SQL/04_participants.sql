-- 3. Participants Table
CREATE TABLE public.participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
    profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(conversation_id, profile_id)
);

-- STRICT RELATIONSHIP LOCK ENFORCEMENT: A user can join at most ONE conversation row at a time.
-- This ensures the private, 1-to-1 nature of the application.
CREATE UNIQUE INDEX unique_user_single_conversation ON public.participants(profile_id);
