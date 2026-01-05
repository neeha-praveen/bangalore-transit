const express = require("express");
const cors = require("cors");

const geocodeAddress = require("./geocode");
const metroStations = require("./data/metroStations.json");
const haversineDistance = require("./utils/distance");
const findMetroRoute = require("./utils/metroRouting");

const app = express();

const sleep = ms => new Promise(r => setTimeout(r, ms));

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 4000;

app.get("/", (req, res) => {
  res.json({ message: "Backend running!" });
});

function buildSteps(stationPath) {
  if (stationPath.length === 1) {
    return [
      { type: "walk", to: stationPath[0].name },
      { type: "exit", at: stationPath[0].name }
    ];
  }

  const steps = [];

  // Walk to first station
  steps.push({
    type: "walk",
    to: stationPath[0].name,
  });

  // helper: find common line between two stations
  function sharedLine(a, b) {
    if (!a?.lines || !b?.lines) return null;
    return a.lines.find(l => b.lines.includes(l));
  }

  // determine starting line (look ahead)
  let currentLine = sharedLine(stationPath[0], stationPath[1]);
  let segmentStart = stationPath[0].name;

  for (let i = 1; i < stationPath.length; i++) {
    const prev = stationPath[i - 1];
    const curr = stationPath[i];

    const nextLine = sharedLine(prev, curr);

    // 🚨 REAL interchange: no shared line
    if (!nextLine || nextLine !== currentLine) {
      // finish previous metro segment
      steps.push({
        type: "metro",
        line: currentLine,
        from: segmentStart,
        to: prev.name,
      });

      // add transfer
      steps.push({
        type: "transfer",
        at: prev.name,
      });

      // start new segment
      currentLine = nextLine;
      segmentStart = curr.name;
    }
  }

  // final metro segment
  steps.push({
    type: "metro",
    line: currentLine,
    from: segmentStart,
    to: stationPath[stationPath.length - 1].name,
  });

  // exit
  steps.push({
    type: "exit",
    at: stationPath[stationPath.length - 1].name,
  });

  return steps;
}

function countLineChanges(stationPath) {
  if (stationPath.length < 2) return 0;

  let changes = 0;

  function sharedLine(a, b) {
    if (!a?.lines || !b?.lines) return null;
    return a.lines.find(l => b.lines.includes(l));
  }

  let currentLine = sharedLine(stationPath[0], stationPath[1]);

  for (let i = 1; i < stationPath.length; i++) {
    const nextLine = sharedLine(stationPath[i - 1], stationPath[i]);
    if (nextLine && nextLine !== currentLine) {
      changes++;
      currentLine = nextLine;
    }
  }

  return changes;
}


app.post("/route", async (req, res) => {
  const { from, to } = req.body;

  try {
    const fromCoords = await geocodeAddress(from);
    await sleep(1000); // To respect Nominatim usage policy
    const toCoords = await geocodeAddress(to);

    if (!fromCoords || !toCoords) {
      return res.status(400).json({
        success: false,
        message: "Unable to geocode one or both addresses",
      });
    }

    function findNearestStations(coords, K = 5) {
      return metroStations
        .map((station) => ({
          station,
          distanceKm: haversineDistance(
            coords.lat,
            coords.lon,
            station.lat,
            station.lon
          ),
        }))
        .sort((a, b) => a.distanceKm - b.distanceKm)
        .slice(0, K);
    }

    function sharedLine(a, b) {
      if (!a?.lines || !b?.lines) return null;
      return a.lines.find(l => b.lines.includes(l));
    }


    const fromCandidates = findNearestStations(fromCoords, 5);
    const toCandidates = findNearestStations(toCoords, 5);

    let bestRoute = null;
    let bestScore = Infinity;
    let bestFrom = null;
    let bestTo = null;

    for (const fromC of fromCandidates) {
      for (const toC of toCandidates) {
        const pathIds = findMetroRoute(
          metroStations,
          fromC.station.id,
          toC.station.id
        );

        if (!pathIds) continue;

        const stationPath = pathIds.map(id =>
          metroStations.find(s => s.id === id)
        );

        const lineChanges = countLineChanges(stationPath);


        // Simple scoring function (can improve later)
        const score =
          fromC.distanceKm * 1.5 +   // walking penalty
          toC.distanceKm * 1.5 +
          pathIds.length +
          lineChanges * 10;           // metro hops

        if (score < bestScore) {
          bestScore = score;
          bestRoute = pathIds;
          bestFrom = fromC;
          bestTo = toC;
        }
      }
    }

    if (!bestRoute) {
      return res.status(404).json({
        success: false,
        message: "No metro route found",
      });
    }

    const stationPath = bestRoute.map((id) =>
      metroStations.find((s) => s.id === id)
    );

    // 🔴 DEBUG: log the raw path
    console.log(
      "STATION PATH:",
      stationPath.map(s => ({
        id: s.id,
        name: s.name,
        lines: s.lines
      }))
    );

    const steps = buildSteps(stationPath);

    const segments = [];

    for (let i = 0; i < stationPath.length - 1; i++) {
      const from = stationPath[i];
      const to = stationPath[i + 1];

      const line = sharedLine(from, to);

      segments.push({
        from: {
          name: from.name,
          lat: from.lat,
          lon: from.lon,
        },
        to: {
          name: to.name,
          lat: to.lat,
          lon: to.lon,
        },
        line, 
      });
    }


    res.json({
      success: true,
      from: {
        lat: bestFrom.station.lat,
        lon: bestFrom.station.lon
      },
      to: {
        lat: bestTo.station.lat,
        lon: bestTo.station.lon
      },
      startStation: bestFrom.station.name,
      endStation: bestTo.station.name,
      metroRoute: stationPath.map((s) => ({
        name: s.name,
        lat: s.lat,
        lon: s.lon,
        line: s.lines,
      })),
      segments,
      steps,
    });


  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: "Geocoding failed" });
  }
});

app.get("/metro-stations", (req, res) => {
  res.json(metroStations);
});


app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
