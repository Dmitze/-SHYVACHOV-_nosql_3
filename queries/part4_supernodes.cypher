// ============================================================
// part4_supernodes.cypher — пошук суперузлів
// Суперузол = вузол з аномально великою кількістю зв'язків
// ============================================================

// ── Суперузли серед фільмів (багато оцінок) ──────────────────
// size([...| 1]) рахує кількість вхідних ребер RATED
// Якщо фільм має > 2000 оцінок — він суперузол
MATCH (m:Movie)
WITH m, size([(m)<-[:RATED]-() | 1]) AS degree
WHERE degree > 2000
RETURN m.title, degree
ORDER BY degree DESC
LIMIT 10;

// ── Суперузли серед жанрів (багато фільмів) ──────────────────
// Жанри Drama і Comedy — класичні суперузли:
// тисячі фільмів мають ці жанри → запит по жанру повільний
MATCH (g:Genre)
WITH g, size([(g)<-[:HAS_GENRE]-() | 1]) AS movieCount
RETURN g.name, movieCount
ORDER BY movieCount DESC;

// ── Суперузли серед користувачів (найактивніші) ───────────────
// Користувачі що оцінили > 1000 фільмів — теж суперузли
MATCH (u:User)
WITH u, size([(u)-[:RATED]->() | 1]) AS degree
WHERE degree > 1000
RETURN u.userId, degree
ORDER BY degree DESC
LIMIT 10;
