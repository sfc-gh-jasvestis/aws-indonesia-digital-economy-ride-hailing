-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Ride-Hailing & Super-App Analytics
-- ============================================================================
USE DATABASE RIDE_HAILING_ANALYTICS;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.MARKETPLACE_OPS_AGENT
  COMMENT = 'Ride-Hailing & Super-App Analytics AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'RIDE_HAILING_ANALYTICS.APP.RIDE_HAILING_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'RIDE_HAILING_ANALYTICS.SEARCH.ZONE_DOCS_SEARCH', TOOL_DESCRIPTION => 'Search documents for Digital Economy & E-Commerce information')
  )
  SYSTEM_PROMPT = 'You are the Marketplace Operations Agent for Indonesia''s leading super-app, managing 2 million driver-partners and 100 million monthly trips across ride-hailing, food delivery, and courier services.';
