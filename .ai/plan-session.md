<conversation_summary>
<decisions>
Przechowywać dane uwierzytelniające oraz nazwę użytkownika.
Implementować kolekcje fiszek z hierarchią ograniczoną do 2 poziomów.
Użytkownicy mogą oznaczać fiszki tagami/kategoriami dla lepszej organizacji.
Przechowywać zarówno oryginalny tekst AI jak i wersję po rewizji użytkownika.
Implementować statystyki akceptacji/rewizji/odrzucenia fiszek AI.
Ograniczyć długość fiszek do 200 znaków (przód) i 500 znaków (tył).
Implementować limit 1000 fiszek na użytkownika w MVP.
Wprowadzić funkcję udostępniania fiszek innym użytkownikom (tylko do odczytu).
Przechowywać tylko najnowsze dane algorytmu powtórek.
Rejestrować sesje nauki z czasem trwania i liczbą przeglądniętych fiszek.
Dodać funkcję eksportu fiszek.
Nie implementować mechanizmu powiadomień w MVP.
</decisions>
<matched_recommendations>
Schemat bazy danych z tabelami: users, collections, flashcards, tags, flashcard_tags, study_sessions, flashcard_reviews, shared_collections.
Implementacja algorytmu SuperMemo-2 (SM-2) dla efektywnego planowania powtórek.
Wykorzystanie Row Level Security (RLS) w Supabase zapewniające, że użytkownicy mają dostęp tylko do własnych danych oraz udostępnionych im fiszek (tylko do odczytu).
Przechowywanie elastycznych metadanych w polach typu JSONB dla statystyk AI i informacji o fiszkach.
Zastosowanie soft delete dla zachowania historii i możliwości odzyskania danych.
Implementacja wyzwalaczy do automatycznej aktualizacji timestampów i egzekwowania limitów fiszek.
Utworzenie widoków dla często wykonywanych zapytań (np. flashcards_due, collection_stats).
Strategiczne indeksowanie dla optymalizacji wydajności zapytań.
Przechowywanie hierarchii kolekcji z ograniczeniem do dwóch poziomów poprzez relację parent_id.
Funkcje przechowywane dla implementacji logiki algorytmu powtórek.
</matched_recommendations>
<database_planning_summary>
Na podstawie przeprowadzonej rozmowy, zaprojektowano schemat bazy danych PostgreSQL (używanej przez Supabase) dla MVP aplikacji 10x-cards służącej do tworzenia i zarządzania fiszkami edukacyjnymi z wykorzystaniem AI.
Główne encje i relacje:
Users - zawiera dane uwierzytelniające, nazwę użytkownika, limit fiszek (1000), statystyki AI oraz timestampy.
Collections - organizacja fiszek w hierarchiczne struktury z ograniczeniem do 2 poziomów poprzez relację parent_id, powiązane z użytkownikiem.
Flashcards - przechowuje zawartość fiszek (przód max 200 znaków, tył max 500 znaków), powiązanie z kolekcją i użytkownikiem, informacje o pochodzeniu (AI vs. manualnie), oryginalną treść AI i metadane w formacie JSONB.
Tags i Flashcard_Tags - mechanizm kategoryzacji fiszek z relacją wiele-do-wielu.
Study_Sessions - rejestracja sesji nauki z czasem trwania i liczbą przeglądniętych fiszek.
Flashcard_Reviews - implementacja algorytmu SM-2 z parametrami ease_factor, interval, repetition_number oraz jakością odpowiedzi, przechowujące tylko najnowsze dane.
Shared_Collections - mechanizm udostępniania kolekcji innym użytkownikom (tylko do odczytu).
Bezpieczeństwo i wydajność:
Row Level Security (RLS) zapewniające, że użytkownicy mają dostęp tylko do własnych danych i udostępnionych im fiszek (tylko odczyt).
Indeksy na kluczach obcych, datach powtórek i zawartości fiszek dla efektywnego wyszukiwania.
Soft delete zamiast fizycznego usuwania, co umożliwia odzyskiwanie danych.
Wyzwalacze do automatycznej aktualizacji timestampów, obliczania dat powtórek i egzekwowania limitów fiszek.
Funkcje przechowywane dla implementacji logiki biznesowej, np. algorytmu powtórek.
Widoki dla uproszczenia często wykonywanych zapytań (fiszki oczekujące na powtórkę, statystyki kolekcji).
Schemat jest zaprojektowany z myślą o MVP, ale uwzględnia potencjalne rozszerzenia w przyszłości, takie jak zwiększenie limitów fiszek czy dodanie nowych funkcjonalności.
</database_planning_summary>
<unresolved_issues>
Dokładny format i implementacja funkcji eksportu fiszek.
Szczegóły procesu zapraszania użytkowników do współdzielenia kolekcji.
Strategie optymalizacji zapytań przy bardzo dużej liczbie fiszek (powyżej limitów MVP).
Ewentualne rozszerzenie funkcjonalności o powiadomienia w przyszłych wersjach.
Szczegóły integracji z frontendem, szczególnie w kontekście implementacji algorytmu SM-2 (czy będzie implementowany całkowicie w bazie danych, czy częściowo w logice aplikacji).
</unresolved_issues>
</conversation_summary>
