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
      // REQUIRED by Nominatim policy
      "User-Agent": "BangaloreTransitApp/1.0 (contact: neeha.npraveen@gmail.com)",
    },
  });

  if (!response.data || response.data.length === 0) {
    return null;
  }

  return {
    lat: parseFloat(response.data[0].lat),
    lon: parseFloat(response.data[0].lon),
  };
}

module.exports = geocodeAddress;
