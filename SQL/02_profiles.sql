-- 1. Profiles Table (extends auth.users)
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username VARCHAR(30) UNIQUE NOT NULL,
    name VARCHAR(50) NOT NULL,
    gender VARCHAR(15), 
    dob TEXT, -- Encrypted date of birth stored as ciphertext
    profile_image TEXT,
    bio VARCHAR(200),
    is_verified BOOLEAN DEFAULT false NOT NULL,
    online_status BOOLEAN DEFAULT false NOT NULL,
    status account_status DEFAULT 'active'::account_status NOT NULL,
    recovery_hash TEXT NOT NULL, -- Argon2id hash of the 16-word recovery phrase
    public_key TEXT, -- E2EE public key stored for key exchange
    dob_changes INT DEFAULT 0 NOT NULL,
    gender_changes INT DEFAULT 0 NOT NULL,
    last_username_change TIMESTAMP WITH TIME ZONE,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();
