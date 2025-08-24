# SunSet API — Rails 8 (Backend)

Fetch and **cache** sunrise/sunset information for a city or coordinates.  
Two delivery modes:

- **Classic JSON**: returns the whole dataset at once  
- **SSE streaming**: sends one record at a time so the UI can render progressively  

Data source: public **Sunrise–Sunset** API.  
Geocoding: **Geocoder (Nominatim / OpenStreetMap)**.

---

## Ruby version

- Ruby 3.4  
- Rails 8.0 (API-only)

---

## System dependencies

- SQLite3  
- Bundler  
- Curl/Postman (optional, for testing)  
- Recommended: run inside **WSL (Ubuntu)** if on Windows

---

## Configuration

No extra configuration needed.  
Environment variables (optional):  
- `PORT`: defaults to `3000`

---

## Database creation

```bash
# clone
git clone https://github.com/andrekrippahl/SunSetAPI.git
cd SunSetAPI

# install gems
bundle install

# database
rails db:setup

# run
rails s
# server: http://localhost:3000
```
---

## Endpoints

### Request
```plaintext
METHOD /sunsets
```
```bash
curl "http://localhost:3000/sunsets?location=Lisbon&start=2025-01-01&end=2025-01-03"
```

```plaintext
METHOD /sunsets
Streams one record per date so the UI can render progressively.
```
```bash
curl -N "http://localhost:3000/sunsets/stream?location=Lisbon&start=2025-01-01&end=2025-01-03"
```

### Response
```json
[
    {
        "id": 405,
        "location": null,
        "date": "2025-08-21",
        "sunrise": "2025-08-21T05:50:46+00:00",
        "sunset": "2025-08-21T19:18:19+00:00",
        "golden_hour": "2025-08-21T05:50:46+00:00 - 2025-08-21T19:18:19+00:00",
        "created_at": "2025-08-23T13:15:50.347Z",
        "updated_at": "2025-08-23T13:15:50.347Z",
        "city": "Beja",
        "latitude": 38.0154479,
        "longitude": -7.8650368
    }
]
```
200 OK

```bash
curl "http://localhost:3000/sunsets?start=2025-01-01&end=2025-01-03"
```

```json
{
    "error": {
        "code": "missing_params",
        "message": "Missing or invalid parameters.",
        "hint": "Required query params: location, start, end.",
        "context": {
            "start": "2025-08-21",
            "end": "2025-08-21"
        }
    }
}
```
400 Bad Request

```bash
curl "http://localhost:3000/sunsets?location=Bejaaa&start=2025-08-21&end=2025-08-21"
```
```json
{
    "error": {
        "code": "geocoding_failed",
        "message": "Could not resolve location.",
        "hint": "Try a city name like 'Lisbon.'",
        "context": {
            "location": "Bejaaa"
        }
    }
}
```
422 Unprocessable Content

---


## Run test suits

```bash 
bundle exec rspec
```

Included request specs cover:
- 400 on missing/invalid params
- 422 when geocoding fails
- Happy path: inserts and returns records
- Uses cached records (no upstream call)
- Maps upstream timeout to 504

---

## Caching & performance

- For a requested range, the controller does one DB query:
WHERE city = ? AND date BETWEEN ? AND ?
- For dates missing in the DB, it:

    - Calls the Sunrise–Sunset API

    - Stores a new sunset_records row

    - Streams/returns the row

- Subsequent requests for the same input are served from DB.

---

## Design decisions / notes

- SSE vs WebSockets
- SSE is simpler for one-way progressive delivery and fits the “append rows as they’re ready” UX.
- DB-first strategy
- Minimizes upstream calls and gives a natural cache. A unique index can enforce idempotency.
- Error architecture
- Domain-level error classes + centralized rescue_from produce a predictable contract for the frontend and make testing straightforward.
- SQLite in dev/test
- Lightweight and fine for the exercise. For production, consider Postgres/MySQL.
- Geocoder
- Nominatim is free but rate-limited; for production use a paid provider (OpenCage, Google).