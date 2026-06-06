-- 5. Ephemeral Connection Codes Table
CREATE TABLE public.pairing_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE, -- Nullable initially until a partner enters the code
    connection_code VARCHAR(6) UNIQUE NOT NULL, 
    status VARCHAR(30) DEFAULT 'waiting' NOT NULL, -- 'waiting', 'pending_acceptance'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Index to quickly check active/expired pairing requests for a user
CREATE INDEX idx_pairing_requests_sender ON public.pairing_requests(sender_id);
