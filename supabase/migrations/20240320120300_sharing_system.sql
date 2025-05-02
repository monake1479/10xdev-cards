-- Migration: Collection sharing system
-- Description: Creates tables and policies for sharing collections between users
-- Author: System
-- Date: 2024-03-20

-- Create shared_collections table
create table shared_collections (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references collections(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  shared_with_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamp with time zone not null default now(),
  
  constraint unique_share unique(collection_id, shared_with_id),
  constraint no_self_share check (owner_id != shared_with_id)
);

-- Enable RLS for shared_collections
alter table shared_collections enable row level security;

comment on table shared_collections is 'Manages collection sharing between users';

-- RLS policies for shared_collections
create policy "Users can view collections shared with them"
  on shared_collections for select
  to authenticated
  using (shared_with_id = auth.uid());

create policy "Users can view collections they shared"
  on shared_collections for select
  to authenticated
  using (owner_id = auth.uid());

create policy "Users can share their collections"
  on shared_collections for insert
  to authenticated
  with check (
    owner_id = auth.uid() and
    exists (
      select 1 from collections
      where id = shared_collections.collection_id
      and user_id = auth.uid()
    )
  );

create policy "Users can remove their shares"
  on shared_collections for delete
  to authenticated
  using (owner_id = auth.uid());

-- Modify existing collection policies to include shared access
drop policy if exists "Users can view own collections" on collections;
create policy "Users can view own and shared collections"
  on collections for select
  to authenticated
  using (
    user_id = auth.uid() or
    id in (
      select collection_id
      from shared_collections
      where shared_with_id = auth.uid()
    )
  );

-- Modify existing flashcard policies to include shared access
drop policy if exists "Users can view own flashcards" on flashcards;
create policy "Users can view own and shared flashcards"
  on flashcards for select
  to authenticated
  using (
    user_id = auth.uid() or
    collection_id in (
      select collection_id
      from shared_collections
      where shared_with_id = auth.uid()
    )
  );

-- Create indexes for better performance
create index idx_shared_collections_owner_id on shared_collections(owner_id);
create index idx_shared_collections_shared_with_id on shared_collections(shared_with_id);
create index idx_shared_collections_collection_id on shared_collections(collection_id); 
