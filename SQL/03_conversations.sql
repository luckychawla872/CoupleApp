-- 2. Conversations Table (strictly holds pair links)
CREATE TABLE public.conversations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    encryption_epoch INT DEFAULT 1 NOT NULL,
    is_verified BOOLEAN DEFAULT false NOT NULL,
    dissolution_state dissolution_status DEFAULT 'none'::dissolution_status NOT NULL,
    dissolution_requested_at TIMESTAMP WITH TIME ZONE,
    dissolution_requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);
