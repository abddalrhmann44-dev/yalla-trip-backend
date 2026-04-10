# Yalla Trip Backend API

Production-ready REST API for the **Yalla Trip** travel & property booking platform targeting the Egyptian market.

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | FastAPI 0.111 |
| Database | PostgreSQL 16 + SQLAlchemy 2.0 (async) |
| Migrations | Alembic |
| Auth | Firebase Admin SDK + JWT |
| Storage | AWS S3 |
| Payments | Fawry gateway |
| Push | FCM |
| Cache | Redis 7 |
| Container | Docker + docker-compose |

## Quick Start

```bash
# 1. Copy environment file
cp .env.example .env
# Edit .env with your actual credentials

# 2. Start all services
docker-compose up -d

# 3. Run migrations
docker-compose exec api alembic upgrade head

# 4. API is live at http://localhost:8000
#    Swagger docs: http://localhost:8000/docs
```

## Project Structure

```
yalla_trip_backend/
├── app/
│   ├── main.py              # FastAPI entry point
│   ├── config.py            # Pydantic settings
│   ├── database.py          # Async SQLAlchemy engine
│   ├── models/              # SQLAlchemy ORM models
│   │   ├── user.py
│   │   ├── property.py
│   │   ├── booking.py
│   │   ├── review.py
│   │   └── notification.py
│   ├── schemas/             # Pydantic request/response schemas
│   │   ├── common.py
│   │   ├── user.py
│   │   ├── property.py
│   │   ├── booking.py
│   │   └── review.py
│   ├── routers/             # API endpoints
│   │   ├── auth.py
│   │   ├── users.py
│   │   ├── properties.py
│   │   ├── bookings.py
│   │   ├── reviews.py
│   │   ├── payments.py
│   │   └── admin.py
│   ├── services/            # External integrations
│   │   ├── firebase_service.py
│   │   ├── s3_service.py
│   │   ├── payment_service.py
│   │   └── notification_service.py
│   └── middleware/
│       ├── auth_middleware.py
│       └── cors_middleware.py
├── alembic/                 # Database migrations
├── tests/                   # pytest test suite
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── .env.example
```

## API Endpoints

### Auth
| Method | Path | Description |
|---|---|---|
| POST | `/auth/verify-token` | Firebase token → JWT |
| POST | `/auth/refresh` | Refresh JWT |
| GET | `/auth/me` | Current user |

### Users
| Method | Path | Description |
|---|---|---|
| GET | `/users/me` | Get profile |
| PUT | `/users/me` | Update profile |
| POST | `/users/me/avatar` | Upload avatar |
| DELETE | `/users/me` | Deactivate account |

### Properties
| Method | Path | Description |
|---|---|---|
| GET | `/properties` | List with filters & pagination |
| GET | `/properties/{id}` | Get single |
| POST | `/properties` | Create (owner) |
| PUT | `/properties/{id}` | Update (owner) |
| DELETE | `/properties/{id}` | Delete (owner) |
| POST | `/properties/{id}/images` | Upload images |

### Bookings
| Method | Path | Description |
|---|---|---|
| POST | `/bookings` | Create booking |
| GET | `/bookings/my` | Guest bookings |
| GET | `/bookings/owner` | Owner bookings |
| PUT | `/bookings/{id}/confirm` | Confirm (owner) |
| PUT | `/bookings/{id}/cancel` | Cancel |
| PUT | `/bookings/{id}/complete` | Complete (owner) |

### Reviews
| Method | Path | Description |
|---|---|---|
| POST | `/reviews` | Create review |
| GET | `/reviews/property/{id}` | Property reviews |

### Payments (Fawry)
| Method | Path | Description |
|---|---|---|
| POST | `/payments/initiate` | Initiate payment |
| POST | `/payments/webhook` | Fawry callback |
| GET | `/payments/status/{booking_id}` | Check status |

### Admin
| Method | Path | Description |
|---|---|---|
| GET | `/admin/users` | List users |
| GET | `/admin/properties` | List properties |
| PUT | `/admin/properties/{id}/approve` | Approve |
| DELETE | `/admin/users/{id}` | Deactivate user |
| GET | `/admin/stats` | Dashboard stats |

## Business Rules

- **Platform fee**: 8% on every booking (configurable)
- **Currency**: EGP (Egyptian Pound)
- **Weekend pricing**: Friday & Saturday use `weekend_price`
- **Instant booking**: Auto-confirm if property has `instant_booking=true`
- **Double-booking prevention**: Date overlap check on every booking
- **Unique booking codes**: 8-character alphanumeric, collision-safe
- **Notifications**: In-app + FCM push on all status changes

## Running Tests

```bash
pip install aiosqlite  # needed for test DB
pytest tests/ -v
```

## Environment Variables

See `.env.example` for the full list. Key ones:

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL async connection string |
| `REDIS_URL` | Redis connection string |
| `SECRET_KEY` | JWT signing key |
| `FIREBASE_CREDENTIALS_JSON` | Firebase service account JSON |
| `AWS_ACCESS_KEY` / `AWS_SECRET_KEY` | S3 credentials |
| `FAWRY_MERCHANT_CODE` / `FAWRY_SECRET_KEY` | Payment gateway |
| `FCM_SERVER_KEY` | Push notifications |

## License

Private – Yalla Trip © 2024
