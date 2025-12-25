const axios = require("axios");

async function geocodeAddress(address) {
  const url = "https://nominatim.openstreetmap.org/search";

  const response = await axios.get(url, {
    params: {
      q: address,
      format: "json",
      limit: 1,
    },
    headers: {
      "User-Agent": "BangaloreTransitApp/1.0",
    },
  });

  if (response.data.length === 0) {
    return null;
  }

  return {
    lat: parseFloat(response.data[0].lat),
    lon: parseFloat(response.data[0].lon),
  };
}

module.exports = geocodeAddress;
