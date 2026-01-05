# Phase 1 – Metro-Only Routing

## Goal
Build a working metro route planner for Bangalore that can determine a valid metro journey between a user’s start and destination locations.

The objective of Phase 1 is correctness and clarity of routing logic, not optimization across multiple transport modes.

---

## Inputs
The system takes the following inputs:
- Start address (user-entered text)
- Destination address (user-entered text)

These addresses are geocoded into latitude and longitude coordinates using a geocoding service.

---

## Approach

### Nearest Station Selection
- All metro stations are stored with their coordinates and associated metro lines.
- The backend computes straight-line (Haversine) distance between the user’s coordinates and each station.
- The closest station to the start point and the closest station to the destination point are selected.

### Metro Network Modeling
- Each metro station is modeled as a node in a graph.
- Edges exist between consecutive stations on the same line.
- Interchange stations naturally connect multiple lines through shared nodes.

### Routing Algorithm
- Breadth-First Search (BFS) is used to traverse the station graph.
- BFS guarantees the shortest path in terms of number of stations traversed.
- The result is an ordered list of stations representing the metro journey.

### Output Generation
- The backend returns:
  - Ordered metro stations (route)
  - Step-by-step instructions (walk, board line, transfer, exit)
  - Line segments for map rendering
- The frontend renders:
  - A timeline-style steps view
  - An interactive map with colored polylines and markers

---

## What Works Correctly
- Station-to-station routing across a single line
- Correct traversal through interchange stations
- End-to-end metro route generation between two user locations
- Visual rendering of routes with line-specific colors
- Step-by-step instructions aligned with the map visualization
