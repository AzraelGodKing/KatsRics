export async function loadJson(name) {
  const res = await fetch(`./data/${name}.json`);
  if (!res.ok) throw new Error(`Failed to load ${name}.json (${res.status})`);
  return res.json();
}

export function fmt(n) {
  return Number(n).toLocaleString();
}
