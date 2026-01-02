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

app.get("/", (req, res) => {
  res.json({ message: "Backend running!" });
});

function buildSteps(stationPath) {
  const steps = [];

  // Walk step
  steps.push({
    type: "walk",
    to: stationPath[0].name,
  });

  let currentLine = stationPath[0].line;
  let segmentStart = stationPath[0].name;

  for (let i = 1; i < stationPath.length; i++) {
    const curr = stationPath[i];

    if (curr.line !== currentLine) {
      // Finish previous metro segment
      steps.push({
        type: "metro",
        line: currentLine,
        from: segmentStart,
        to: stationPath[i - 1].name,
      });

      // Transfer
      steps.push({
        type: "transfer",
        at: stationPath[i - 1].name,
      });

      currentLine = curr.line;
      segmentStart = curr.name;
    }
  }

  // Final metro segment
  steps.push({
    type: "metro",
    line: currentLine,
    from: segmentStart,
    to: stationPath[stationPath.length - 1].name,
  });

  // Exit
  steps.push({
    type: "exit",
    at: stationPath[stationPath.length - 1].name,
  });

  return steps;
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

        // Simple scoring function (can improve later)
        const score =
          fromC.distanceKm * 1.5 +   // walking penalty
          toC.distanceKm * 1.5 +
          pathIds.length;            // metro hops

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

    const steps = buildSteps(stationPath);

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
        line: s.line,
      })),

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


app.listen(4000, () => {
  console.log("Server running on port 4000");
});
