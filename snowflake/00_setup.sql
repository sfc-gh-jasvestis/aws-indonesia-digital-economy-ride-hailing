-- Generated from generator/demo_specs/aws-indonesia-digital-economy-ride-hailing.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-indonesia-digital-economy-ride-hailing
-- This is the schema that is actually deployed for ID_DIGITAL_ECONOMY_RIDE_HAILING.

-- ID_DIGITAL_ECONOMY_RIDE_HAILING  (Ride-Hailing & Super-App Analytics)
-- generated from generator/demo_specs/aws-indonesia-digital-economy-ride-hailing.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS ID_DIGITAL_ECONOMY_RIDE_HAILING;
CREATE SCHEMA IF NOT EXISTS ID_DIGITAL_ECONOMY_RIDE_HAILING.RAW;
CREATE SCHEMA IF NOT EXISTS ID_DIGITAL_ECONOMY_RIDE_HAILING.CURATED;
CREATE SCHEMA IF NOT EXISTS ID_DIGITAL_ECONOMY_RIDE_HAILING.APP;
USE DATABASE ID_DIGITAL_ECONOMY_RIDE_HAILING;

-- 5 real regions; entity names carry their region so the two always agree
