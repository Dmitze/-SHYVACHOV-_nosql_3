import csv
import os

# Створюємо папку import/ якщо вона ще не існує
os.makedirs("import", exist_ok=True)

# ── Конвертація movies.dat → movies.csv ──────────────────────
# Формат вхідного файлу: MovieID::Title::Genres
# Жанри розділені символом | (наприклад: Action|Comedy|Drama)
with open("movies.dat", encoding="latin-1") as f_in, \
     open("import/movies.csv", "w", newline="", encoding="utf-8") as f_out:
    writer = csv.writer(f_out)
    writer.writerow(["movieId", "title", "genres"])  # заголовок
    for line in f_in:
        parts = line.strip().split("::")
        if len(parts) == 3:  # пропускаємо некоректні рядки
            writer.writerow(parts)

# ── Конвертація ratings.dat → ratings.csv ────────────────────
# Формат вхідного файлу: UserID::MovieID::Rating::Timestamp
# Rating — від 1 до 5, Timestamp — час у секундах (Unix time)
with open("ratings.dat", encoding="latin-1") as f_in, \
     open("import/ratings.csv", "w", newline="", encoding="utf-8") as f_out:
    writer = csv.writer(f_out)
    writer.writerow(["userId", "movieId", "rating", "timestamp"])
    for line in f_in:
        parts = line.strip().split("::")
        if len(parts) == 4:
            writer.writerow(parts)

# ── Конвертація users.dat → users.csv ────────────────────────
# Формат вхідного файлу: UserID::Gender::Age::Occupation::Zip
# Zip-код нам не потрібен — беремо тільки перші 4 поля
with open("users.dat", encoding="latin-1") as f_in, \
     open("import/users.csv", "w", newline="", encoding="utf-8") as f_out:
    writer = csv.writer(f_out)
    writer.writerow(["userId", "gender", "age", "occupation"])
    for line in f_in:
        parts = line.strip().split("::")
        if len(parts) >= 4:
            writer.writerow(parts[:4])  # беремо тільки перші 4 колонки

print("✅ Готово! CSV-файли створені в папці import/")
print("   movies.csv | users.csv | ratings.csv")
