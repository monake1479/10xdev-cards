-- Migration: Disable all RLS policies
-- Description: Disables all previously defined Row Level Security policies
-- Author: System
-- Date: 2024-03-20

-- Disable policies for user_profiles
drop policy if exists "Users can view own profile" on user_profiles;
drop policy if exists "Users can update own profile" on user_profiles;

-- Disable policies for collections
drop policy if exists "Users can view own collections" on collections;
drop policy if exists "Users can create collections" on collections;
drop policy if exists "Users can update own collections" on collections;
drop policy if exists "Users can view own and shared collections" on collections;

-- Disable policies for flashcards
drop policy if exists "Users can view own flashcards" on flashcards;
drop policy if exists "Users can create flashcards" on flashcards;
drop policy if exists "Users can update own flashcards" on flashcards;
drop policy if exists "Users can view own and shared flashcards" on flashcards;

-- Disable policies for tags
drop policy if exists "Users can view own tags" on tags;
drop policy if exists "Users can create tags" on tags;
drop policy if exists "Users can delete own tags" on tags;

-- Disable policies for flashcard_tags
drop policy if exists "Users can view own flashcard tags" on flashcard_tags;
drop policy if exists "Users can manage own flashcard tags" on flashcard_tags;
drop policy if exists "Users can remove own flashcard tags" on flashcard_tags;

-- Disable policies for study_sessions
drop policy if exists "Users can view own study sessions" on study_sessions;
drop policy if exists "Users can create study sessions" on study_sessions;
drop policy if exists "Users can update own study sessions" on study_sessions;

-- Disable policies for flashcard_reviews
drop policy if exists "Users can view own flashcard reviews" on flashcard_reviews;
drop policy if exists "Users can create flashcard reviews" on flashcard_reviews;
drop policy if exists "Users can update own flashcard reviews" on flashcard_reviews; 
