-- 4. Messages Table (E2EE payload encrypted on client side)
CREATE TABLE public.messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL, -- Nullable to support account deletion without losing chat history
    encrypted_payload TEXT NOT NULL, 
    nonce TEXT NOT NULL,             
    msg_type message_type DEFAULT 'text'::message_type NOT NULL,
    status VARCHAR(20) DEFAULT 'sent' NOT NULL, -- Tracking 'sent', 'delivered', 'read' statuses
    encrypted_reactions TEXT, -- Stores E2EE encrypted JSON of message reactions
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    delivered_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    is_edited BOOLEAN DEFAULT false NOT NULL,
    parent_message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL
);

-- Index to optimize fetching recent message history
CREATE INDEX idx_messages_conversation_sent_at ON public.messages(conversation_id, sent_at DESC);
