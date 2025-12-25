const express = require("express");
const cors = require("cors");

const geocodeAddress = require("./geocode");
const metroStations = require("./data/metroStations.json");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.json({ message: "Backend running!" });
});

app.post("/route", async (req, res) => {
  const { from, to } = req.body;

  try {
    const fromCoords = await geocodeAddress(from);
    const toCoords = await geocodeAddress(to);

    if (!fromCoords || !toCoords) {
      return res.status(400).json({
        success: false,
        message: "Unable to geocode one or both addresses",
      });
    }

    res.json({
      success: true,
      from: {
        address: from,
        coordinates: fromCoords,
      },
      to: {
        address: to,
        coordinates: toCoords,
      },
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
