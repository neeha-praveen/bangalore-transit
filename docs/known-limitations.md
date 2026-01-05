# Known Limitations

This document outlines known limitations of the Phase 1 implementation and the reasons they exist.

---

## Nearest Station Accuracy
The system selects nearest stations using straight-line (Haversine) distance.

In dense urban areas, this can result in:
- Stations that are geographically close but poorly accessible by road
- Suboptimal starting stations when physical barriers exist

This is an accepted tradeoff in Phase 1.

---

## Road vs Straight-Line Distance
Walking distance is not calculated using the road network.

As a result:
- Estimated walking effort may be inaccurate
- Some suggested stations may be impractical in real-world conditions

Road-network distance calculations are planned for future phases.

---

## Direction and Platform Ambiguity
The system determines which line to take but does not:
- Specify platform sides
- Account for direction-specific entrances
- Handle terminal-bound train direction explicitly

These details are intentionally omitted to keep routing logic station-focused.

---

## No Multimodal Support
Phase 1 only supports metro travel.

The system does not:
- Suggest bus routes
- Combine walking, bus, and metro
- Optimize across different transport modes

Multimodal routing is planned for Phase 2.

---

## Static Data Assumptions
Metro station data is static and does not account for:
- Service disruptions
- Timetable variations
- Live congestion or crowding

The routing logic assumes ideal operating conditions.
