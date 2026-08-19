# Vue catalog

Source lives in `web/` (Vue 3 + Vite). GitHub Pages still serves `docs/`.

```powershell
powershell -NoProfile -File scripts/generate-docs-data.ps1
cd web
npm install
npm run dev      # local preview
npm run build    # writes into ../docs
```
