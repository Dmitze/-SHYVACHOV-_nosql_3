// ============================================================
// part3.cypher — 6 запитів різної складності
// Після кожного запиту зроби скріншот результату (перших 10 рядків)
// ============================================================

// ── Запит 1: Трилери з середнім рейтингом > 4.0 ──────────────
// Знаходимо фільми жанру Thriller, рахуємо середній рейтинг,
// фільтруємо: тільки ті де avg > 4.0 і оцінок не менше 10
MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre {name: 'Thriller'})
MATCH (u:User)-[r:RATED]->(m)
WITH m, avg(r.rating) AS avgRating, count(r) AS cnt
WHERE avgRating > 4.0 AND cnt >= 10
RETURN m.title, round(avgRating * 100)/100 AS avgRating, cnt
ORDER BY avgRating DESC
LIMIT 20;

// ── Запит 2: Найактивніші "п'ятизірочники" ───────────────────
// Знаходимо користувачів які поставили оцінку 5
// більш ніж 50 фільмам
MATCH (u:User)-[r:RATED]->(m:Movie)
WHERE r.rating = 5
WITH u, count(m) AS fiveStarCount
WHERE fiveStarCount > 50
RETURN u.userId, u.gender, u.age, fiveStarCount
ORDER BY fiveStarCount DESC
LIMIT 20;

// ── Запит 3: Спільні фільми двох користувачів ────────────────
// Знаходимо фільми які обидва користувачі (1 і 2) оцінили >= 4
// Зміни userId якщо результат порожній (спробуй 1 і 100)
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.title, r1.rating AS rating_user1, r2.rating AS rating_user2
ORDER BY r1.rating + r2.rating DESC;

// ── Запит 4: Жанри зі стабільно високими оцінками ────────────
// Для кожного жанру рахуємо середній рейтинг і кількість оцінок.
// Фільтр >= 1000 щоб виключити жанри з малою вибіркою
MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre)
MATCH (u:User)-[r:RATED]->(m)
WITH g, avg(r.rating) AS avgRating, count(r) AS totalRatings
WHERE totalRatings >= 1000
RETURN g.name AS genre,
       round(avgRating * 100)/100 AS avgRating,
       totalRatings
ORDER BY avgRating DESC;

// ── Запит 5: Рекомендація "схожі користувачі також дивились" ─
// Алгоритм collaborative filtering:
// 1. Знаходимо користувачів зі схожими смаками (спільні фільми >= 3)
// 2. Дивимось що ще вони дивились з рейтингом >= 4
// 3. Виключаємо фільми які target вже бачив
// 4. Сортуємо за кількістю рекомендацій і середнім рейтингом
MATCH (target:User {userId: 1})-[r1:RATED]->(common:Movie)<-[r2:RATED]-(similar:User)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND target <> similar
WITH target, similar, count(common) AS sharedMovies
WHERE sharedMovies >= 3
ORDER BY sharedMovies DESC LIMIT 20
MATCH (similar)-[r3:RATED]->(rec:Movie)
WHERE r3.rating >= 4
  AND NOT (target)-[:RATED]->(rec)
RETURN rec.title,
       count(similar) AS recommendedBy,
       avg(r3.rating) AS avgScore
ORDER BY recommendedBy DESC, avgScore DESC
LIMIT 20;

// ── Запит 6: Найкоротший шлях між двома користувачами ────────
// shortestPath шукає найкоротший маршрут по ребрах RATED
// *..6 означає максимум 6 кроків (3 проміжних вузли)
// Один хоп: User → Film. Шлях довжини 2: обидва оцінили один фільм
MATCH (u1:User {userId: 1}), (u2:User {userId: 500})
MATCH path = shortestPath((u1)-[:RATED*..6]-(u2))
RETURN path, length(path) AS pathLength;
