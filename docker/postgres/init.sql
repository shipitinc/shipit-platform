-- ShipIt Platform PostgreSQL initialization
-- Runs on first container startup

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Set timezone
SET timezone = 'UTC';

-- Serverpod will manage schema via migrations
-- This file ensures extensions are available before migrations run