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

function buildDirections(stationPath) {
  const steps = [];

  // Walk to first station
  steps.push(`Walk to ${stationPath[0].name} Metro Station`);

  let currentLine = stationPath[0].line;
  steps.push(`Board ${currentLine} Line`);

  for (let i = 1; i < stationPath.length; i++) {
    const curr = stationPath[i];

    // Only announce when line ACTUALLY changes
    if (curr.line !== currentLine && curr.line !== "Interchange") {
      steps.push(`Change to ${curr.line} Line at ${stationPath[i - 1].name}`);
      currentLine = curr.line;
    }
  }

  steps.push(`Exit at ${stationPath[stationPath.length - 1].name}`);
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

    function findNearestStation(coords) {
      let nearest = null;
      let minDistance = Infinity;

      for (const station of metroStations) {
        const dist = haversineDistance(
          coords.lat,
          coords.lon,
          station.lat,
          station.lon
        );

        if (dist < minDistance) {
          minDistance = dist;
          nearest = station;
        }
      }

      return { station: nearest, distanceKm: minDistance };
    }

    const fromNearest = findNearestStation(fromCoords);
    const toNearest = findNearestStation(toCoords);

    const startStationId = fromNearest.station.id;
    const endStationId = toNearest.station.id;

    const stationPathIds = findMetroRoute(
      metroStations,
      startStationId,
      endStationId
    );

    if (!stationPathIds) {
      return res.status(404).json({
        success: false,
        message: "No metro route found",
      });
    }

    const stationPath = stationPathIds.map((id) =>
      metroStations.find((s) => s.id === id)
    );

    const directions = buildDirections(stationPath);

    res.json({
      success: true,
      from: {
        lat: fromNearest.station.lat,
        lon: fromNearest.station.lon
      },
      to: {
        lat: toNearest.station.lat,
        lon: toNearest.station.lon
      },
      startStation: fromNearest.station.name,
      endStation: toNearest.station.name,
      metroRoute: stationPath.map((s) => ({
        name: s.name,
        lat: s.lat,
        lon: s.lon,
        line: s.line,
      })),

      directions,
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
