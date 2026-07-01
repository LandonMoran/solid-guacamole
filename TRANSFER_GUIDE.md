# Transfer Guide: Nightzuku Android 17 Support to Shizuku

This guide explains how to transfer the work from solid-guacamole to your Shizuku repository without needing git push credentials.

## What's Included

- **nightzuku-port.bundle** — Complete git bundle with all branches and history
- **patches/** — Individual commit patches you can apply
- **This guide** — Step-by-step instructions

---

## Option 1: Using Git Bundle (Recommended)

The bundle file contains all branches and can be imported directly.

### Prerequisites
- Git installed
- Local clone of your Shizuku repository

### Steps

1. **Download the bundle file** to your local machine

2. **In your Shizuku repo**, add the bundle as a remote:
   ```bash
   cd ~/path/to/your/Shizuku
   git remote add bundle /path/to/nightzuku-port.bundle
   ```

3. **Fetch the branches** from the bundle:
   ```bash
   git fetch bundle
   ```

4. **Create tracking branches** (pick the ones you need):
   ```bash
   # For the complete integration with Android 17 support
   git checkout -b nightzuku-port bundle/claude/nightzuku-clone-8l6vp2
   
   # Or for just Android 17 support
   git checkout -b android17-only bundle/shizuku-android17
   
   # Or for the base
   git checkout -b shizuku-base bundle/shizuku-master
   ```

5. **Push to your repository**:
   ```bash
   git push origin nightzuku-port
   ```

6. **Create a pull request** from the new branch in your GitHub repo

---

## Option 2: Using Patch Files

If the bundle approach doesn't work, use individual patches.

### Steps

1. **Download all patch files** to a local directory

2. **In your Shizuku repo**, create a new branch:
   ```bash
   git checkout -b nightzuku-port
   ```

3. **Apply the patches** in order:
   ```bash
   git am /path/to/patches/*.patch
   ```

4. **Resolve any conflicts** if they occur:
   ```bash
   # After fixing conflicts
   git add .
   git am --continue
   ```

5. **Push to your repository**:
   ```bash
   git push origin nightzuku-port
   ```

6. **Create a pull request** from the new branch in your GitHub repo

---

## Option 3: Manual GitHub Web UI Transfer

If you can't use git locally, you can transfer via GitHub's web interface.

### Steps

1. **Go to your Shizuku repo** on GitHub

2. **Click "New branch"** (or navigate to /tree/new)

3. **Create branch from commit** — Enter the commit SHA from the branch you want:
   - `claude/nightzuku-clone-8l6vp2`: `54d0f278b69f84dbf1193fb2a8fbe6d4d3863d8f`
   - `shizuku-android17`: `edae275c745c7e4393696d46022a61214d196cb2`
   - `shizuku-master`: `482629e168f2ffa0002b53561b30c6f6bffda3ab`

4. **Name the new branch** (e.g., `nightzuku-port`)

5. **Create pull request** from the new branch

---

## File Locations

- Bundle: `nightzuku-port.bundle`
- Patches: `patches/0001-*.patch` through `patches/0004-*.patch`
- Build config: `gradle.properties`, `gradle.properties.compileSdk36`
- Fallback variants: `build.gradle.compileSdk36`, `thedjchi-shizuku/build.gradle.compileSdk36`

---

## What Each Branch Contains

### `claude/nightzuku-clone-8l6vp2` (Recommended)
- Complete Nightzuku v13.6.0.r51 clone
- thedjchi/Shizuku v13.6.0.r1318-thedjchi fork
- Android 17 support ported from Nightzuku
- Full build configuration (compileSdk 37)
- Fallback variants for compatibility

### `shizuku-android17`
- Base Shizuku fork with Android 17 support
- Smaller diff, easier to review

### `shizuku-master`
- Base Shizuku fork only
- CI baseline

---

## Verification

After transferring, verify the work:

```bash
# Check the branch exists
git branch -a

# Verify the commits
git log --oneline -5

# Check the build files
cat gradle.properties
```

---

## Questions?

- The work is fully committed and ready in solid-guacamole
- All branches are available and public
- The bundle is self-contained and doesn't require any credentials
