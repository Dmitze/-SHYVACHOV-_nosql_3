// ============================================================
// part2_load.cypher — індекси та завантаження даних
// Виконуй запити по одному в Neo4j Browser
// ============================================================

// ── Крок 1: Створення індексів ───────────────────────────────
// Індекс = як зміст у книзі. Без нього Neo4j шукає перебором,
// з індексом — знаходить миттєво. Створюємо ДО завантаження ребер!
CREATE INDEX user_id    IF NOT EXISTS FOR (u:User)  ON (u.userId);
CREATE INDEX movie_id   IF NOT EXISTS FOR (m:Movie) ON (m.movieId);
CREATE INDEX genre_name IF NOT EXISTS FOR (g:Genre) ON (g.name);

// ── Крок 2: Завантаження користувачів ────────────────────────
// LOAD CSV читає файл рядок за рядком
// MERGE = створити якщо не існує (захист від дублікатів)
// SET = встановити властивості вузла
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
SET u.gender     = row.gender,
    u.age        = toInteger(row.age),
    u.occupation = toInteger(row.occupation);

// ── Крок 3: Завантаження фільмів та жанрів ───────────────────
// UNWIND розгортає список жанрів: "Action|Comedy" → два окремих рядки
// Для кожного жанру створюємо вузол Genre і зв'язок HAS_GENRE
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
SET m.title = row.title,
    m.year  = toInteger(substring(row.title, size(row.title)-5, 4))
WITH m, row
UNWIND split(row.genres, '|') AS genre
MERGE (g:Genre {name: genre})
MERGE (m)-[:HAS_GENRE]->(g);

// ── Крок 4: Завантаження оцінок батчами ──────────────────────
// 1 мільйон записів не можна завантажити однією транзакцією —
// впаде через нестачу пам'яті. apoc.periodic.iterate ділить
// роботу на батчі по 10 000 записів кожен.
// parallel: false — послідовно, щоб уникнути конфліктів запису
CALL apoc.periodic.iterate(
  "LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row RETURN row",
  "MATCH (u:User  {userId:  toInteger(row.userId)})
   MATCH (m:Movie {movieId: toInteger(row.movieId)})
   MERGE (u)-[r:RATED]->(m)
   SET r.rating    = toFloat(row.rating),
       r.timestamp = toInteger(row.timestamp)",
  {batchSize: 10000, parallel: false}
);

// ── Крок 5: Перевірка завантаження ───────────────────────────
// Запускай кожен рядок окремо і порівнюй з очікуваними числами
MATCH (u:User)         RETURN count(u)  AS users;    // очікується ~6040
MATCH (m:Movie)        RETURN count(m)  AS movies;   // очікується ~3883
MATCH ()-[r:RATED]->() RETURN count(r)  AS ratings;  // очікується ~1 000 209
