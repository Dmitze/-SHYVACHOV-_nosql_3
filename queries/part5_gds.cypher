// ============================================================
// part5_gds.cypher — алгоритми Graph Data Science
// Виконуй кожен блок послідовно. Не пропускай кроки очистки!
// ============================================================


// ════════════════════════════════════════════════════════════
// 5.1 PageRank — важливість фільмів у графі
// PageRank вимірює не просто популярність, а центральність:
// фільм важливий якщо його дивляться разом з іншими важливими фільмами
// ════════════════════════════════════════════════════════════

// Крок 1: матеріалізуємо ребра фільм↔фільм через спільних глядачів
// Якщо два фільми оцінили >= 4 зіркам одні й ті самі люди — з'єднуємо їх
// LIMIT 50000 щоб не перевантажити пам'ять
MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(m1) < id(m2)
WITH m1, m2, count(u) AS weight
WHERE size([(m1)<-[:RATED]-() | 1]) > 20
  AND size([(m2)<-[:RATED]-() | 1]) > 20
WITH m1, m2, weight ORDER BY weight DESC LIMIT 50000
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight;

// Крок 2: створюємо проекцію графа в пам'яті GDS
// GDS не працює напряму зі збереженим графом — потрібна проекція
CALL gds.graph.project(
  'movieGraph',  // назва проекції
  'Movie',       // які вузли включаємо
  { CO_RATED: { orientation: 'UNDIRECTED', properties: 'weight' } }
) YIELD graphName, nodeCount, relationshipCount;

// Крок 3: запускаємо PageRank
// dampingFactor: 0.85 — стандартне значення (як в оригінальному Google)
// maxIterations: 20 — кількість ітерацій до збіжності
CALL gds.pageRank.stream('movieGraph', {
  maxIterations: 20,
  dampingFactor: 0.85
})
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS movie, score
RETURN movie.title AS title, score
ORDER BY score DESC LIMIT 10;

// Крок 4: обов'язково видаляємо проекцію і тимчасові ребра
// Якщо не видалити — наступний запуск впаде з помилкою "вже існує"
CALL gds.graph.drop('movieGraph');
MATCH ()-[co:CO_RATED]-() DELETE co;


// ════════════════════════════════════════════════════════════
// 5.2 Louvain — виявлення спільнот користувачів
// Louvain групує вузли в кластери де зв'язки всередині
// щільніші ніж назовні. Ми знайдемо групи користувачів
// зі схожими смаками у фільмах.
// ════════════════════════════════════════════════════════════

// Крок 1: матеріалізуємо ребра користувач↔користувач
// Якщо двоє дали >= 4 зірок одним і тим самим фільмам — вони "схожі"
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
ORDER BY weight DESC LIMIT 50000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;

// Крок 2: проекція для алгоритму
CALL gds.graph.project(
  'userSimilarity',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
) YIELD graphName, nodeCount, relationshipCount;

// Крок 3: запускаємо Louvain — отримуємо розміри кластерів
CALL gds.louvain.stream('userSimilarity')
YIELD nodeId, communityId
WITH gds.util.asNode(nodeId) AS user, communityId
RETURN communityId, count(user) AS size
ORDER BY size DESC LIMIT 10;

// Крок 4: визначаємо топ-3 жанри для кожного кластера
// Це дозволяє зрозуміти "характер" кожної спільноти
CALL gds.louvain.stream('userSimilarity')
YIELD nodeId, communityId
WITH gds.util.asNode(nodeId) AS user, communityId
MATCH (user)-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE r.rating >= 4
WITH communityId, g.name AS genre, count(*) AS cnt
ORDER BY communityId, cnt DESC
WITH communityId, collect({genre: genre, cnt: cnt})[..3] AS topGenres
RETURN communityId, topGenres ORDER BY communityId;

// Крок 5: очищення
CALL gds.graph.drop('userSimilarity');
MATCH ()-[sim:SIMILAR]-() DELETE sim;


// ════════════════════════════════════════════════════════════
// 5.3 Dijkstra — найкоротший шлях між користувачами
// Алгоритм Дейкстри знаходить оптимальний шлях у зваженому графі.
// Тут "вага" ребра = кількість спільних фільмів (більше = ближче).
// ════════════════════════════════════════════════════════════

// Крок 1: пересоздаємо граф схожості (якщо видалили в 5.2)
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
ORDER BY weight DESC LIMIT 50000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;

CALL gds.graph.project(
  'userGraph',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
) YIELD graphName, nodeCount, relationshipCount;

// Крок 2: запускаємо Dijkstra між двома користувачами
// Спробуй різні пари userId щоб порівняти довжини шляхів
MATCH (source:User {userId: 1}), (target:User {userId: 500})
CALL gds.shortestPath.dijkstra.stream('userGraph', {
  sourceNode: source,
  targetNode: target,
  relationshipWeightProperty: 'weight'
})
YIELD nodeIds, totalCost
RETURN [id IN nodeIds | gds.util.asNode(id).userId] AS шлях,
       totalCost AS загальнаВага,
       size(nodeIds) - 1 AS кількістьКроків;

// Крок 3: очищення
CALL gds.graph.drop('userGraph');
MATCH ()-[sim:SIMILAR]-() DELETE sim;
