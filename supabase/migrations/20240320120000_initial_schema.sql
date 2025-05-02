-- Migration: Initial schema for 10x-cards
-- Description: Creates core tables for user profiles, collections, and flashcards
-- Author: System
-- Date: 2024-03-20

-- Enable pgcrypto for UUID generation
create extension if not exists "pgcrypto";

-- Create user_profiles table
create table user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  flashcard_limit integer not null default 1000,
  ai_stats jsonb default '{"generated": 0, "accepted": 0, "revised": 0, "rejected": 0}'::jsonb,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  last_login_at timestamp with time zone,
  is_deleted boolean not null default false,
  deleted_at timestamp with time zone
);

-- Enable RLS for user_profiles
alter table user_profiles enable row level security;

-- RLS policies for user_profiles
comment on table user_profiles is 'Stores extended user profile information';

-- Allow users to view their own profile
create policy "Users can view own profile"
  on user_profiles for select
  to authenticated
  using (id = auth.uid());

-- Allow users to update their own profile
create policy "Users can update own profile"
  on user_profiles for update
  to authenticated
  using (id = auth.uid());

-- Create collections table
create table collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text,
  parent_id uuid references collections(id) on delete cascade,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  is_deleted boolean not null default false,
  deleted_at timestamp with time zone,
  
  constraint valid_hierarchy check (
    parent_id is null or parent_id != id
  )
);

-- Enable RLS for collections
alter table collections enable row level security;

comment on table collections is 'Stores flashcard collections with optional hierarchical structure';

-- RLS policies for collections
create policy "Users can view own collections"
  on collections for select
  to authenticated
  using (user_id = auth.uid() and is_deleted = false);

create policy "Users can create collections"
  on collections for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "Users can update own collections"
  on collections for update
  to authenticated
  using (user_id = auth.uid());

-- Create flashcards table
create table flashcards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  collection_id uuid not null references collections(id) on delete cascade,
  front text not null check (char_length(front) <= 200),
  back text not null check (char_length(back) <= 500),
  is_ai_generated boolean not null default false,
  original_ai_front text,
  original_ai_back text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  is_deleted boolean not null default false,
  deleted_at timestamp with time zone
);

-- Enable RLS for flashcards
alter table flashcards enable row level security;

comment on table flashcards is 'Stores flashcard content with AI generation tracking';

-- RLS policies for flashcards
create policy "Users can view own flashcards"
  on flashcards for select
  to authenticated
  using (user_id = auth.uid() and is_deleted = false);

create policy "Users can create flashcards"
  on flashcards for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "Users can update own flashcards"
  on flashcards for update
  to authenticated
  using (user_id = auth.uid());

-- Create indexes for better performance
create index idx_flashcards_user_id on flashcards(user_id);
create index idx_flashcards_collection_id on flashcards(collection_id);
create index idx_flashcards_is_ai_generated on flashcards(is_ai_generated);
create index idx_flashcards_is_deleted on flashcards(is_deleted);

create index idx_collections_user_id on collections(user_id);
create index idx_collections_parent_id on collections(parent_id);
create index idx_collections_is_deleted on collections(is_deleted); 
