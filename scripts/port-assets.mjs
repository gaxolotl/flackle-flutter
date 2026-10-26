// Ports Flackle Desktop's bundled visual assets into the Flutter app.
// Source assets live in the repository root (src/, public/), never in flutter/.
import { mkdir, writeFile, readFile, cp, readdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";

const repo = path.resolve(import.meta.dirname, "..", "..");
const out = path.resolve(import.meta.dirname, "..", "assets");

async function ensure(dir) {
  await mkdir(dir, { recursive: true });
}

function escapeAttr(value) {
  return value.replaceAll("&", "&amp;").replaceAll('"', "&quot;");
}

// 1. Stroke icon set from Icon.svelte
{
  const source = await readFile(path.join(repo, "src/lib/components/Icon.svelte"), "utf8");
  const block = source.slice(source.indexOf("const paths"), source.indexOf("</script>"));
  const icons = {};
  const re = /^\s{4}([A-Za-z0-9_]+):\s*(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)')/gm;
  let match;
  while ((match = re.exec(block))) {
    icons[match[1]] = match[2] ?? match[3];
  }
  const dir = path.join(out, "icons");
  await ensure(dir);
  for (const [name, d] of Object.entries(icons)) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="${escapeAttr(d)}"/></svg>\n`;
    await writeFile(path.join(dir, `${name}.svg`), svg);
  }
  console.log(`icons: ${Object.keys(icons).length}`);
}

// 2. Filled channel-icon set from channel-icons.ts
{
  const source = await readFile(path.join(repo, "src/lib/channel-icons.ts"), "utf8");
  const start = source.indexOf("{", source.indexOf("channelIcons"));
  const body = source.slice(start, source.lastIndexOf("}") + 1);
  const icons = Function(`"use strict"; return (${body});`)();
  const dir = path.join(out, "channel-icons");
  await ensure(dir);
  let count = 0;
  for (const [name, parts] of Object.entries(icons)) {
    if (!Array.isArray(parts) || parts.length === 0) continue;
    const paths = parts
      .map(
        (part) =>
          `<path d="${escapeAttr(part.d)}"${part.fillRule ? ` fill-rule="${part.fillRule}"` : ""}${part.clipRule ? ` clip-rule="${part.clipRule}"` : ""}/>`,
      )
      .join("");
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">${paths}</svg>\n`;
    await writeFile(path.join(dir, `${name}.svg`), svg);
    count += 1;
  }
  console.log(`channel icons: ${count}`);
}

// 3. Brand mark from Mark.svelte
{
  const source = await readFile(path.join(repo, "src/lib/components/Mark.svelte"), "utf8");
  const paths = [...source.matchAll(/d="([^"]+)"/g)].map((match) => match[1]);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 139 139" fill="none">${paths
    .map((d) => `<path d="${escapeAttr(d)}" fill="currentColor"/>`)
    .join("")}</svg>\n`;
  const dir = path.join(out, "brand");
  await ensure(dir);
  await writeFile(path.join(dir, "mark.svg"), svg);
  for (const file of ["flackle-icon.png", "favicon.ico"]) {
    const sourcePath = path.join(repo, "public/brand", file);
    if (existsSync(sourcePath)) await cp(sourcePath, path.join(dir, file));
  }
  console.log("brand: mark.svg + raster assets");
}

// 4. Emoji SVG library
{
  const sourceDir = path.join(repo, "public/emoji");
  const targetDir = path.join(out, "emoji");
  await ensure(targetDir);
  const files = await readdir(sourceDir);
  let copied = 0;
  for (const file of files) {
    if (!file.endsWith(".svg")) {
      if (file.startsWith("LICENSE")) {
        await cp(path.join(sourceDir, file), path.join(targetDir, file));
      }
      continue;
    }
    await cp(path.join(sourceDir, file), path.join(targetDir, file));
    copied += 1;
  }
  console.log(`emoji: ${copied}`);
}

// 5. Emoji metadata as JSON
{
  const source = await readFile(path.join(repo, "src/lib/emoji-data.ts"), "utf8");
  const start = source.indexOf("[", source.indexOf("emojiCategories"));
  const body = source.slice(start, source.lastIndexOf("]") + 1);
  const categories = Function(`"use strict"; return (${body});`)();
  const slim = categories.map((category) => ({
    id: category.id,
    label: category.label,
    entries: (category.entries ?? []).map((entry) => ({
      char: entry.char,
      name: entry.name,
      keywords: entry.keywords,
      file: entry.file,
    })),
  }));
  await writeFile(path.join(out, "emoji_data.json"), JSON.stringify(slim));
  const total = slim.reduce((sum, category) => sum + category.entries.length, 0);
  console.log(`emoji metadata: ${slim.length} categories, ${total} entries`);
}

// 6. Fonts: Flutter needs TrueType, so the woff2 files are converted separately
//    by scripts/convert-fonts.py. Copy the originals for reference only when a
//    converted TTF is missing.
{
  const dir = path.join(out, "fonts");
  await ensure(dir);
  for (const font of ["manrope-variable.woff2", "satoshi-variable.woff2", "satoshi-italic.woff2"]) {
    const target = path.join(dir, font.replace(".woff2", ".ttf"));
    if (existsSync(target)) continue;
    console.log(`fonts: missing ${path.basename(target)} (run scripts/convert-fonts.py)`);
  }
}
