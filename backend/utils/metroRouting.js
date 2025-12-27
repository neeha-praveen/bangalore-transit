function findMetroRoute(stations, startId, endId) {
  const queue = [[startId]];
  const visited = new Set();

  while (queue.length > 0) {
    const path = queue.shift();
    const current = path[path.length - 1];

    if (current === endId) {
      return path;
    }

    if (!visited.has(current)) {
      visited.add(current);

      const station = stations.find((s) => s.id === current);
      if (!station) continue;

      for (const neighbor of station.connections) {
        if (!visited.has(neighbor)) {
          queue.push([...path, neighbor]);
        }
      }
    }
  }

  return null;
}

module.exports = findMetroRoute;
