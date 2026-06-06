-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom enums
CREATE TYPE message_type AS ENUM ('text', 'image', 'system');
CREATE TYPE device_platform AS ENUM ('android', 'web', 'windows');
CREATE TYPE account_status AS ENUM ('active', 'pending_deletion');
CREATE TYPE dissolution_status AS ENUM ('none', 'pending', 'dissolved');
