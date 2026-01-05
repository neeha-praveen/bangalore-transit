# Design Decisions

This document explains the reasoning behind key technical decisions made in Phase 1.

---

## Why BFS Instead of Dijkstra
Breadth-First Search was selected because metro networks have:
- Fixed stop order
- Near-uniform edge weights (each station hop is similar in cost)
- No dynamic weights in Phase 1

Using Dijkstra would introduce unnecessary complexity without improving route quality at this stage. BFS provides a simpler and more maintainable solution while still guaranteeing the shortest station path.

---

## Why Haversine Distance Was Used Initially
Haversine distance provides a fast and dependency-free way to approximate proximity between user locations and metro stations.

At this stage:
- Road-network accuracy is not required
- The goal is to identify a reasonable nearby station
- Performance and simplicity are prioritized

More accurate road-distance calculations are intentionally deferred to later phases.

---

## Why Routing Is Station-Based in Phase 1
Phase 1 focuses exclusively on metro travel, where:
- Routes are naturally defined by stations
- Users reason about journeys in terms of stations and lines
- The metro network is static and predictable

Station-based routing keeps the graph small, understandable, and easy to validate before introducing additional transport modes.

---

## Why Visualization Is Coupled With Routing Output
The backend returns structured routing data (stations, segments, line names) rather than raw geometry.

This design allows the frontend to:
- Render polylines with line-specific colors
- Place interchange markers accurately
- Display step-by-step instructions consistent with the visual route

Keeping routing semantics explicit improves debuggability and enables future multimodal extensions without redesigning the API.
