-- Migration: Study system implementation
-- Description: Creates tables and functions for tracking study sessions and flashcard reviews
-- Author: System
-- Date: 2024-03-20

-- Create study_sessions table
create table study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamp with time zone not null default now(),
  ended_at timestamp with time zone,
  duration_seconds integer,
  cards_reviewed integer not null default 0,
  collection_id uuid references collections(id) on delete set null
);

-- Enable RLS for study_sessions
alter table study_sessions enable row level security;

comment on table study_sessions is 'Tracks user study sessions and their statistics';

-- RLS policies for study_sessions
create policy "Users can view own study sessions"
  on study_sessions for select
  to authenticated
  using (user_id = auth.uid());

create policy "Users can create study sessions"
  on study_sessions for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "Users can update own study sessions"
  on study_sessions for update
  to authenticated
  using (user_id = auth.uid());

-- Create flashcard_reviews table
create table flashcard_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  flashcard_id uuid not null references flashcards(id) on delete cascade,
  study_session_id uuid references study_sessions(id) on delete set null,
  reviewed_at timestamp with time zone not null default now(),
  next_review_at timestamp with time zone not null,
  ease_factor numeric(4,3) not null default 2.5,
  interval integer not null default 0,
  repetition_number integer not null default 0,
  quality integer not null check (quality between 0 and 5),
  
  constraint unique_user_flashcard unique(user_id, flashcard_id)
);

-- Enable RLS for flashcard_reviews
alter table flashcard_reviews enable row level security;

comment on table flashcard_reviews is 'Stores spaced repetition data for flashcard reviews';

-- RLS policies for flashcard_reviews
create policy "Users can view own flashcard reviews"
  on flashcard_reviews for select
  to authenticated
  using (user_id = auth.uid());

create policy "Users can create flashcard reviews"
  on flashcard_reviews for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "Users can update own flashcard reviews"
  on flashcard_reviews for update
  to authenticated
  using (user_id = auth.uid());

-- Create SM-2 algorithm function
create or replace function calculate_next_review(
  quality integer,
  current_ef numeric,
  current_interval integer,
  current_repetition integer
) returns table(
  new_ef numeric,
  new_interval integer,
  new_repetition integer,
  next_review timestamp with time zone
) as $$
declare
  new_ef numeric;
  new_interval integer;
  new_repetition integer;
begin
  -- Calculate new ease factor (EF)
  new_ef := current_ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  if new_ef < 1.3 then
    new_ef := 1.3;
  end if;
  
  -- Calculate new interval and repetition count
  if quality < 3 then
    new_interval := 1;
    new_repetition := 0;
  else
    new_repetition := current_repetition + 1;
    
    if new_repetition = 1 then
      new_interval := 1;
    elsif new_repetition = 2 then
      new_interval := 6;
    else
      new_interval := round(current_interval * new_ef);
    end if;
  end if;
  
  return query select 
    new_ef,
    new_interval,
    new_repetition,
    now() + (new_interval * interval '1 day');
end;
$$ language plpgsql;

-- Create indexes for better performance
create index idx_flashcard_reviews_user_id on flashcard_reviews(user_id);
create index idx_flashcard_reviews_flashcard_id on flashcard_reviews(flashcard_id);
create index idx_flashcard_reviews_next_review_at on flashcard_reviews(next_review_at);

create index idx_study_sessions_user_id on study_sessions(user_id);
create index idx_study_sessions_started_at on study_sessions(started_at); 
