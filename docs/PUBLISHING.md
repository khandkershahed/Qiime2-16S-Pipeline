# Publishing to GitHub + releasing versions

## First publish (v1.0.0)

### 1) Create the GitHub repository
- GitHub → **New repository**
- Name example: `qiime2-16s-multiregion-snakemake`
- Choose **Public** (recommended for researchers)
- Do **not** auto-create README (this repo already includes it)

### 2) Push your code
From the repo folder:
```bash
git init
git add .
git commit -m "Release v1.0.0: research-safe multi-region pipeline"
git branch -M main
git remote add origin https://github.com/<USERNAME>/<REPO>.git
git push -u origin main
```

### 3) Tag and push version v1.0.0
```bash
git tag -a v1.0.0 -m "v1.0.0 research-safe release"
git push origin v1.0.0
```

### 4) Create a GitHub Release
GitHub → **Releases** → **Draft a new release**
- Tag: `v1.0.0`
- Title: `v1.0.0`
- Paste release notes (short: what it does + what you tested)
- Publish

## Releasing an updated version later (example: v1.0.1)

### 1) Commit your changes
```bash
git add .
git commit -m "Describe the update"
git push
```

### 2) Tag a new version
```bash
git tag -a v1.0.1 -m "v1.0.1 bugfix release"
git push origin v1.0.1
```

### 3) Create the GitHub Release
GitHub → Releases → Draft new release → choose tag `v1.0.1` → Publish
