-- Migration: Functions, triggers and views
-- Description: Creates additional database functions, triggers and views for enhanced functionality
-- Author: System
-- Date: 2024-03-20

-- Create updated_at timestamp function
create or replace function update_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Create triggers for updated_at timestamps
create trigger update_user_profiles_timestamp
  before update on user_profiles
  for each row execute function update_timestamp();

create trigger update_collections_timestamp
  before update on collections
  for each row execute function update_timestamp();

create trigger update_flashcards_timestamp
  before update on flashcards
  for each row execute function update_timestamp();

-- Create function for handling new users
create or replace function handle_new_user() 
returns trigger as $$
begin
  insert into user_profiles (id, username)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

-- Create trigger for new user handling
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Create function for checking flashcard limits
create or replace function check_flashcard_limit()
returns trigger as $$
declare
  current_count integer;
  user_limit integer;
begin
  select count(*) into current_count
  from flashcards
  where user_id = new.user_id and is_deleted = false;
  
  select flashcard_limit into user_limit
  from user_profiles
  where id = new.user_id;
  
  if current_count >= user_limit then
    raise exception 'Przekroczono limit fiszek dla użytkownika';
  end if;
  
  return new;
end;
$$ language plpgsql;

-- Create trigger for flashcard limit checking
create trigger check_flashcard_limit_trigger
  before insert on flashcards
  for each row execute function check_flashcard_limit();

-- Create function for updating AI stats
create or replace function update_ai_stats()
returns trigger as $$
begin
  if new.is_ai_generated = true then
    update user_profiles
    set ai_stats = jsonb_set(
      jsonb_set(ai_stats, '{generated}', (coalesce((ai_stats->>'generated')::int, 0) + 1)::text::jsonb),
      '{accepted}', (coalesce((ai_stats->>'accepted')::int, 0) + 1)::text::jsonb
    )
    where id = new.user_id;
  end if;
  return new;
end;
$$ language plpgsql;

-- Create trigger for AI stats updates
create trigger update_ai_stats_trigger
  after insert on flashcards
  for each row
  when (new.is_ai_generated = true)
  execute function update_ai_stats();

-- Create view for due flashcards
create or replace view flashcards_due as
select f.id, f.user_id, f.collection_id, f.front, f.back, 
       r.next_review_at, r.ease_factor, r.interval, r.repetition_number
from flashcards f
join flashcard_reviews r on f.id = r.flashcard_id
where f.is_deleted = false
  and r.next_review_at <= now();

comment on view flashcards_due is 'Shows flashcards that are due for review';

-- Create view for collection statistics
create or replace view collection_stats as
select c.id, c.user_id, c.name, 
       count(f.id) as total_flashcards,
       sum(case when f.is_ai_generated then 1 else 0 end) as ai_generated_count,
       avg(r.ease_factor) as avg_ease_factor
from collections c
left join flashcards f on c.id = f.collection_id and f.is_deleted = false
left join flashcard_reviews r on f.id = r.flashcard_id
where c.is_deleted = false
group by c.id, c.user_id, c.name;

comment on view collection_stats is 'Provides statistics for each collection';

-- Create view for shared collections
create or replace view user_shared_collections as
select u.id as user_id, c.id as collection_id, c.name, c.description,
       sc.owner_id, up.username as owner_username
from auth.users u
join shared_collections sc on u.id = sc.shared_with_id
join collections c on sc.collection_id = c.id
join user_profiles up on sc.owner_id = up.id
where c.is_deleted = false;

comment on view user_shared_collections is 'Shows collections shared with each user';

-- Create view for user details
create or replace view user_details as
select 
  u.id,
  u.email,
  u.last_sign_in_at,
  p.username,
  p.flashcard_limit,
  p.ai_stats,
  p.is_deleted
from auth.users u
left join user_profiles p on u.id = p.id;

comment on view user_details is 'Combines user authentication and profile data'; 
