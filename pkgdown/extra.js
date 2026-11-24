// Draw plain ```mermaid blocks from README.md on the pkgdown home page.
// Quarto {mermaid} cells (pre.mermaid-js) render themselves and are skipped.
document.addEventListener("DOMContentLoaded", async () => {
  const sel = "pre.mermaid:not(.mermaid-js), pre.sourceCode.mermaid, code.language-mermaid";
  const boxes = new Set([...document.querySelectorAll(sel)].map(
    (el) => el.closest("div.sourceCode") || el.closest("pre") || el));
  if (!boxes.size) return;
  const { default: mermaid } = await import(
    "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.esm.min.mjs");
  mermaid.initialize({ startOnLoad: false });
  for (const box of boxes) {
    const div = document.createElement("div");
    div.className = "mermaid";
    div.textContent = box.textContent;
    box.replaceWith(div);
  }
  await mermaid.run({ querySelector: "div.mermaid" });
});
