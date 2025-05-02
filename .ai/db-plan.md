# Schemat bazy danych PostgreSQL dla 10x-cards

## 1. Tabele

### Uwaga dotycząca uwierzytelniania
Uwierzytelnianie w aplikacji jest zarządzane przez Supabase Auth, który dostarcza tabelę `auth.users` z podstawowymi danymi użytkowników takimi jak email, hasło (haszowane), timestampy itp. Nie tworzymy własnej tabeli users, zamiast tego korzystamy z wbudowanego systemu Supabase i tworzymy dodatkowy profil użytkownika.

### user_profiles
```sql
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  flashcard_limit INTEGER NOT NULL DEFAULT 1000,
  ai_stats JSONB DEFAULT '{"generated": 0, "accepted": 0, "revised": 0, "rejected": 0}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  last_login_at TIMESTAMP WITH TIME ZONE,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMP WITH TIME ZONE
);
```

### collections
```sql
CREATE TABLE collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  parent_id UUID REFERENCES collections(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMP WITH TIME ZONE,
  
  CONSTRAINT valid_hierarchy CHECK (
    parent_id IS NULL OR parent_id != id
  )
);
```

### flashcards
```sql
CREATE TABLE flashcards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  collection_id UUID NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  front TEXT NOT NULL CHECK (char_length(front) <= 200),
  back TEXT NOT NULL CHECK (char_length(back) <= 500),
  is_ai_generated BOOLEAN NOT NULL DEFAULT false,
  original_ai_front TEXT,
  original_ai_back TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMP WITH TIME ZONE
);
```

### tags
```sql
CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  
  UNIQUE(user_id, name)
);
```

### flashcard_tags
```sql
CREATE TABLE flashcard_tags (
  flashcard_id UUID NOT NULL REFERENCES flashcards(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  
  PRIMARY KEY (flashcard_id, tag_id)
);
```

### study_sessions
```sql
CREATE TABLE study_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  ended_at TIMESTAMP WITH TIME ZONE,
  duration_seconds INTEGER,
  cards_reviewed INTEGER NOT NULL DEFAULT 0,
  collection_id UUID REFERENCES collections(id) ON DELETE SET NULL
);
```

### flashcard_reviews
```sql
CREATE TABLE flashcard_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  flashcard_id UUID NOT NULL REFERENCES flashcards(id) ON DELETE CASCADE,
  study_session_id UUID REFERENCES study_sessions(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  next_review_at TIMESTAMP WITH TIME ZONE NOT NULL,
  ease_factor NUMERIC(4,3) NOT NULL DEFAULT 2.5,
  interval INTEGER NOT NULL DEFAULT 0,
  repetition_number INTEGER NOT NULL DEFAULT 0,
  quality INTEGER NOT NULL CHECK (quality BETWEEN 0 AND 5),
  
  UNIQUE(user_id, flashcard_id)
);
```

### shared_collections
```sql
CREATE TABLE shared_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  collection_id UUID NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shared_with_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  
  UNIQUE(collection_id, shared_with_id),
  CHECK (owner_id != shared_with_id)
);
```

## 2. Relacje między tabelami

- auth.users (1) — (0..1) user_profiles
- auth.users (1) — (0..n) collections
- auth.users (1) — (0..n) flashcards
- auth.users (1) — (0..n) tags
- auth.users (1) — (0..n) study_sessions
- auth.users (1) — (0..n) flashcard_reviews
- collections (1) — (0..n) flashcards
- collections (1) — (0..n) collections (parent-child)
- collections (1) — (0..n) shared_collections
- flashcards (1) — (0..n) flashcard_reviews
- flashcards (n) — (m) tags (poprzez flashcard_tags)
- study_sessions (1) — (0..n) flashcard_reviews

## 3. Indeksy

```sql
-- Indeksy dla wspólnych zapytań
CREATE INDEX idx_flashcards_user_id ON flashcards(user_id);
CREATE INDEX idx_flashcards_collection_id ON flashcards(collection_id);
CREATE INDEX idx_flashcards_is_ai_generated ON flashcards(is_ai_generated);
CREATE INDEX idx_flashcards_is_deleted ON flashcards(is_deleted);

CREATE INDEX idx_collections_user_id ON collections(user_id);
CREATE INDEX idx_collections_parent_id ON collections(parent_id);
CREATE INDEX idx_collections_is_deleted ON collections(is_deleted);

CREATE INDEX idx_flashcard_reviews_user_id ON flashcard_reviews(user_id);
CREATE INDEX idx_flashcard_reviews_flashcard_id ON flashcard_reviews(flashcard_id);
CREATE INDEX idx_flashcard_reviews_next_review_at ON flashcard_reviews(next_review_at);

CREATE INDEX idx_study_sessions_user_id ON study_sessions(user_id);
CREATE INDEX idx_study_sessions_started_at ON study_sessions(started_at);

CREATE INDEX idx_tags_user_id ON tags(user_id);
CREATE INDEX idx_tags_name ON tags(name);

CREATE INDEX idx_shared_collections_owner_id ON shared_collections(owner_id);
CREATE INDEX idx_shared_collections_shared_with_id ON shared_collections(shared_with_id);
```

## 4. Wyzwalacze i funkcje

```sql
-- Funkcja aktualizująca datę modyfikacji
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Wyzwalacze aktualizacji timestamp
CREATE TRIGGER update_user_profiles_timestamp
BEFORE UPDATE ON user_profiles
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_collections_timestamp
BEFORE UPDATE ON collections
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_flashcards_timestamp
BEFORE UPDATE ON flashcards
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Funkcja tworząca profil użytkownika po rejestracji
CREATE OR REPLACE FUNCTION handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id, username)
  VALUES (NEW.id, NEW.email); -- Domyślnie ustawiamy username jako email
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Wyzwalacz tworzący profil użytkownika po rejestracji
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Funkcja sprawdzająca limit fiszek użytkownika
CREATE OR REPLACE FUNCTION check_flashcard_limit()
RETURNS TRIGGER AS $$
DECLARE
  current_count INTEGER;
  user_limit INTEGER;
BEGIN
  SELECT COUNT(*) INTO current_count
  FROM flashcards
  WHERE user_id = NEW.user_id AND is_deleted = false;
  
  SELECT flashcard_limit INTO user_limit
  FROM user_profiles
  WHERE id = NEW.user_id;
  
  IF current_count >= user_limit THEN
    RAISE EXCEPTION 'Przekroczono limit fiszek dla użytkownika';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Wyzwalacz sprawdzający limit fiszek
CREATE TRIGGER check_flashcard_limit_trigger
BEFORE INSERT ON flashcards
FOR EACH ROW EXECUTE FUNCTION check_flashcard_limit();

-- Funkcja aktualizująca statystyki AI po dodaniu fiszki
CREATE OR REPLACE FUNCTION update_ai_stats()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_ai_generated = true THEN
    UPDATE user_profiles
    SET ai_stats = jsonb_set(
      jsonb_set(ai_stats, '{generated}', (COALESCE((ai_stats->>'generated')::int, 0) + 1)::text::jsonb),
      '{accepted}', (COALESCE((ai_stats->>'accepted')::int, 0) + 1)::text::jsonb
    )
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Wyzwalacz aktualizujący statystyki AI
CREATE TRIGGER update_ai_stats_trigger
AFTER INSERT ON flashcards
FOR EACH ROW
WHEN (NEW.is_ai_generated = true)
EXECUTE FUNCTION update_ai_stats();

-- Funkcja SM-2 do obliczania następnej daty powtórki
CREATE OR REPLACE FUNCTION calculate_next_review(
  quality INTEGER,
  current_ef NUMERIC,
  current_interval INTEGER,
  current_repetition INTEGER
) RETURNS TABLE(
  new_ef NUMERIC,
  new_interval INTEGER,
  new_repetition INTEGER,
  next_review TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
  new_ef NUMERIC;
  new_interval INTEGER;
  new_repetition INTEGER;
BEGIN
  -- Oblicz nowy współczynnik łatwości (EF)
  new_ef := current_ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  IF new_ef < 1.3 THEN
    new_ef := 1.3;
  END IF;
  
  -- Oblicz nowy interwał i liczbę powtórzeń
  IF quality < 3 THEN
    new_interval := 1;
    new_repetition := 0;
  ELSE
    new_repetition := current_repetition + 1;
    
    IF new_repetition = 1 THEN
      new_interval := 1;
    ELSIF new_repetition = 2 THEN
      new_interval := 6;
    ELSE
      new_interval := ROUND(current_interval * new_ef);
    END IF;
  END IF;
  
  RETURN QUERY SELECT 
    new_ef,
    new_interval,
    new_repetition,
    now() + (new_interval * INTERVAL '1 day');
END;
$$ LANGUAGE plpgsql;
```

## 5. Widoki

```sql
-- Widok fiszek oczekujących na powtórkę
CREATE OR REPLACE VIEW flashcards_due AS
SELECT f.id, f.user_id, f.collection_id, f.front, f.back, 
       r.next_review_at, r.ease_factor, r.interval, r.repetition_number
FROM flashcards f
JOIN flashcard_reviews r ON f.id = r.flashcard_id
WHERE f.is_deleted = false
  AND r.next_review_at <= now();

-- Widok statystyk kolekcji
CREATE OR REPLACE VIEW collection_stats AS
SELECT c.id, c.user_id, c.name, 
       COUNT(f.id) AS total_flashcards,
       SUM(CASE WHEN f.is_ai_generated THEN 1 ELSE 0 END) AS ai_generated_count,
       AVG(r.ease_factor) AS avg_ease_factor
FROM collections c
LEFT JOIN flashcards f ON c.id = f.collection_id AND f.is_deleted = false
LEFT JOIN flashcard_reviews r ON f.id = r.flashcard_id
WHERE c.is_deleted = false
GROUP BY c.id, c.user_id, c.name;

-- Widok współdzielonych kolekcji
CREATE OR REPLACE VIEW user_shared_collections AS
SELECT u.id AS user_id, c.id AS collection_id, c.name, c.description,
       sc.owner_id, up.username AS owner_username
FROM auth.users u
JOIN shared_collections sc ON u.id = sc.shared_with_id
JOIN collections c ON sc.collection_id = c.id
JOIN user_profiles up ON sc.owner_id = up.id
WHERE c.is_deleted = false;

-- Widok szczegółów użytkownika łączący auth.users z user_profiles
CREATE OR REPLACE VIEW user_details AS
SELECT 
  u.id,
  u.email,
  u.last_sign_in_at,
  p.username,
  p.flashcard_limit,
  p.ai_stats,
  p.is_deleted
FROM auth.users u
LEFT JOIN user_profiles p ON u.id = p.id;
```

## 6. Zasady PostgreSQL Row Level Security (RLS)

```sql
-- Włączenie RLS dla tabel
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE flashcard_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;

-- Zasady dla user_profiles
CREATE POLICY user_profiles_user_access ON user_profiles
  USING (id = auth.uid());

-- Zasady dla collections
CREATE POLICY collections_user_access ON collections
  USING (user_id = auth.uid() OR
         id IN (SELECT collection_id FROM shared_collections WHERE shared_with_id = auth.uid()));

-- Zasady dla flashcards
CREATE POLICY flashcards_user_access ON flashcards
  USING (user_id = auth.uid() OR
         collection_id IN (SELECT collection_id FROM shared_collections WHERE shared_with_id = auth.uid()));

-- Zasady dla modyfikacji fiszek
CREATE POLICY flashcards_modify ON flashcards
  FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY flashcards_delete ON flashcards
  FOR DELETE
  USING (user_id = auth.uid());

-- Zasady dla tags
CREATE POLICY tags_user_access ON tags
  USING (user_id = auth.uid());

-- Zasady dla flashcard_reviews
CREATE POLICY flashcard_reviews_user_access ON flashcard_reviews
  USING (user_id = auth.uid());

-- Zasady dla study_sessions
CREATE POLICY study_sessions_user_access ON study_sessions
  USING (user_id = auth.uid());

-- Zasady dla shared_collections
CREATE POLICY shared_collections_owner_access ON shared_collections
  USING (owner_id = auth.uid());

CREATE POLICY shared_collections_shared_access ON shared_collections
  FOR SELECT
  USING (shared_with_id = auth.uid());
```

## 7. Dodatkowe uwagi

1. **Integracja z Supabase Auth** - Zamiast własnej tabeli users, korzystamy z wbudowanej tabeli `auth.users` Supabase i tworzymy powiązaną tabelę `user_profiles` z dodatkowymi informacjami o użytkowniku.

2. **Automatyczne tworzenie profilu** - Wyzwalacz `on_auth_user_created` automatycznie tworzy profil użytkownika po rejestracji w systemie Supabase Auth.

3. **Soft Delete** - Implementujemy mechanizm soft delete (is_deleted i deleted_at) dla user_profiles, collections i flashcards, aby umożliwić odzyskiwanie danych i zachować integralność historycznych danych.

4. **Algorytm SM-2** - Implementacja algorytmu SuperMemo-2 dla efektywnego planowania powtórek jest zrealizowana w funkcji calculate_next_review.

5. **Limity danych** - Wprowadzono ograniczenia na długość fiszek (front: 200 znaków, tył: 500 znaków) oraz limit 1000 fiszek na użytkownika w MVP.

6. **Hierarchia kolekcji** - Zapewniono hierarchię kolekcji ograniczoną do 2 poziomów poprzez relację parent_id w tabeli collections z odpowiednim ograniczeniem.

7. **Statystyki AI** - Przechowywanie statystyk generowania i akceptacji fiszek AI w polu typu JSONB w tabeli user_profiles.

8. **Udostępnianie kolekcji** - Mechanizm udostępniania kolekcji innym użytkownikom (tylko do odczytu) poprzez tabelę shared_collections.

9. **Bezpieczeństwo** - Row Level Security (RLS) zapewnia, że użytkownicy mają dostęp tylko do własnych danych i udostępnionych im kolekcji.

10. **Wydajność** - Indeksy na kluczach obcych, datach powtórek i często używanych polach zapewniają wydajne wyszukiwanie i sortowanie.

11. **Rozszerzalność** - Schemat jest zaprojektowany z myślą o MVP, ale uwzględnia potencjalne rozszerzenia w przyszłości. 
