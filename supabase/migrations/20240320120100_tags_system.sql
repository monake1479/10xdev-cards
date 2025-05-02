-- Migration: Tags system for flashcards
-- Description: Creates tables and relations for flashcard tagging functionality
-- Author: System
-- Date: 2024-03-20

-- Create tags table
create table tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamp with time zone not null default now(),
  
  constraint unique_user_tag unique(user_id, name)
);

-- Enable RLS for tags
alter table tags enable row level security;

comment on table tags is 'Stores user-created tags for flashcard categorization';

-- RLS policies for tags
create policy "Users can view own tags"
  on tags for select
  to authenticated
  using (user_id = auth.uid());

create policy "Users can create tags"
  on tags for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "Users can delete own tags"
  on tags for delete
  to authenticated
  using (user_id = auth.uid());

-- Create flashcard_tags junction table
create table flashcard_tags (
  flashcard_id uuid not null references flashcards(id) on delete cascade,
  tag_id uuid not null references tags(id) on delete cascade,
  
  primary key (flashcard_id, tag_id)
);

-- Enable RLS for flashcard_tags
alter table flashcard_tags enable row level security;

comment on table flashcard_tags is 'Junction table connecting flashcards with their tags';

-- RLS policies for flashcard_tags
create policy "Users can view own flashcard tags"
  on flashcard_tags for select
  to authenticated
  using (
    exists (
      select 1 from flashcards
      where id = flashcard_tags.flashcard_id
      and user_id = auth.uid()
    )
  );

create policy "Users can manage own flashcard tags"
  on flashcard_tags for insert
  to authenticated
  with check (
    exists (
      select 1 from flashcards
      where id = flashcard_tags.flashcard_id
      and user_id = auth.uid()
    )
  );

create policy "Users can remove own flashcard tags"
  on flashcard_tags for delete
  to authenticated
  using (
    exists (
      select 1 from flashcards
      where id = flashcard_tags.flashcard_id
      and user_id = auth.uid()
    )
  );

-- Create indexes for better performance
create index idx_tags_user_id on tags(user_id);
create index idx_tags_name on tags(name);
create index idx_flashcard_tags_flashcard_id on flashcard_tags(flashcard_id);
create index idx_flashcard_tags_tag_id on flashcard_tags(tag_id); 
