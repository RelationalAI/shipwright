# Widget Configuration Guide

## Overview

This guide covers how to configure widgets in the Acme platform. Widgets are the primary unit of user-facing functionality.

## Authentication

All widget API calls require a bearer token. Tokens expire after 24 hours. Use the `/auth/token` endpoint to refresh.

The maximum number of concurrent sessions per user is 5.

## Rate Limiting

Widget API calls are rate-limited to 100 requests per minute per user. Exceeding this limit returns HTTP 429.

Rate limit headers are included in every response:
- `X-RateLimit-Limit`: 100
- `X-RateLimit-Remaining`: requests left in the current window
- `X-RateLimit-Reset`: UTC epoch timestamp when the window resets

## Widget Lifecycle

Widgets go through these states: `draft` → `active` → `archived`.

A widget in `draft` state is only visible to its creator. Once activated, it becomes visible to all users with the appropriate role.

Archiving a widget is irreversible. All associated data is retained for 90 days, then permanently deleted.

## Permissions

Widget access is controlled by roles:
- `admin`: full CRUD access to all widgets
- `editor`: can create and modify own widgets
- `viewer`: read-only access

The maximum number of concurrent sessions per user is 5.

## Error Handling

All errors return a JSON body with `code`, `message`, and `request_id` fields. The `request_id` should be included in support tickets.

Common error codes:
- `WIDGET_NOT_FOUND`: The widget ID does not exist
- `WIDGET_ARCHIVED`: Attempted to modify an archived widget
- `RATE_LIMITED`: Too many requests (see Rate Limiting section)
