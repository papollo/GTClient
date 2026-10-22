# Build Guide

This document explains how to produce a release build of **OTClient Redemption** from source on Linux, Windows, and macOS. The client is a cross-platform C++20 application that relies on CMake and vcpkg to fetch third-party dependencies.【F:README.md†L25-L27】【F:CMakeLists.txt†L1-L20】

## 1. Repository layout and runtime assets
A working production bundle consists of the compiled `otclient` binary plus the Lua scripts, configuration files, and assets that ship with the repository. When packaging the client, make sure the following items accompany the executable:

* `data/` – core assets such as appearances, sounds, and configuration files loaded at runtime.【F:Dockerfile†L42-L45】
* `modules/` – Lua UI and gameplay modules required for the client shell.【F:Dockerfile†L42-L45】
* `mods/` – optional Lua mods; include at least the bundled README so the directory is discovered.【F:tools/make_snapshot.sh†L205-L225】
* `init.lua` – the Lua bootstrap script executed on startup.【F:Dockerfile†L42-L47】
* `otclientrc.lua` – default runtime configuration copied into release packages.【F:tools/make_snapshot.sh†L215-L223】
* Any legal and documentation files (`LICENSE`, `README.md`, etc.) you want to distribute with the build.【F:tools/make_snapshot.sh†L221-L225】

## 2. Toolchain prerequisites

| Component | Notes |
|-----------|-------|
| Git | Required to clone the source tree.
| CMake ≥ 3.22 | Presets require at least CMake 3.22.【F:CMakePresets.json†L1-L7】
| Ninja (preferred) | Official presets configure Ninja builds on every desktop platform.【F:CMakePresets.json†L12-L139】
| C++20 compiler | The code base targets C++20; use GCC 14+, Clang 16+, or MSVC 19.3x.【F:README.md†L25-L27】【F:.github/workflows/build-ubuntu.yml†L55-L65】
| vcpkg | Dependency manager used through CMake’s toolchain integration.【F:CMakeLists.txt†L8-L20】
| Platform SDKs | Linux requires X11/OpenGL headers; Windows requires the Desktop development workload; macOS requires Xcode command line tools.【F:Dockerfile†L6-L39】【F:src/CMakeLists.txt†L181-L235】

### Recommended OS-specific packages

* **Linux (Debian/Ubuntu)** – install the packages used by the Docker image and CI pipeline:
  ```bash
  sudo apt-get update
  sudo apt-get install -y build-essential cmake ninja-build git libglew-dev libx11-dev linux-headers-$(uname -r)
  ```
  GCC 14 is known to work and can be selected via `update-alternatives` if multiple toolchains are installed.【F:.github/workflows/build-ubuntu.yml†L55-L65】
* **Windows** – install Visual Studio 2022 (Desktop development with C++), Ninja, and ensure `VCPKG_ROOT` points to your vcpkg checkout so the CMake preset can find the toolchain file.【F:CMakePresets.json†L10-L38】【F:.github/workflows/build-windows.yml†L55-L112】
* **macOS** – install Xcode command line tools plus Homebrew packages `cmake` and `ninja` before invoking the presets.【F:CMakePresets.json†L120-L151】

## 3. Set up vcpkg dependencies

1. Clone the repository and create (or reuse) a vcpkg tree:
   ```bash
   git clone https://github.com/mehah/otclient.git
   cd otclient
   git submodule update --init --recursive
   ```
2. Checkout vcpkg at the baseline commit required by the manifest and bootstrap it:
   ```bash
   git clone https://github.com/microsoft/vcpkg.git "$HOME/vcpkg"
   cd "$HOME/vcpkg"
   git checkout b322364f06308bdd24823f9d8f03fe0cc86fd46f
   ./bootstrap-vcpkg.sh  # or .\bootstrap-vcpkg.bat on Windows
   ```
   This mirrors the process in the Dockerfile so your host build uses the exact dependency versions.【F:Dockerfile†L13-L23】
3. Point `VCPKG_ROOT` to that checkout and let CMake drive manifest mode. The manifest enumerates all required libraries (asio, abseil, Protobuf, LuaJIT, OpenAL/OpenGL, etc.) so running vcpkg is enough to download and build them on demand.【F:vcpkg.json†L4-L41】

## 4. Configure a release build

You can rely on the provided CMake presets for each desktop operating system. Each preset configures a Release-with-Debug-Info build that uses the vcpkg toolchain and out-of-source build directories under `build/<preset>`.【F:CMakePresets.json†L12-L186】 Prior to configuring, ensure the environment variable `VCPKG_ROOT` is set to the vcpkg path you bootstrapped in the previous step.【F:CMakeLists.txt†L11-L20】

### Linux
```bash
cmake --preset linux-release
cmake --build --preset linux-release --target otclient
```
The preset selects the Ninja generator, enables ccache, and uses the host’s vcpkg triplet `x64-linux`. The build output lands in `build/linux-release/bin/` alongside its shared libraries.【F:CMakePresets.json†L55-L118】【F:.github/workflows/build-ubuntu.yml†L114-L135】

### Windows
```powershell
cmake --preset windows-release
cmake --build --preset windows-release --target otclient
```
This generates a static 64-bit executable using Ninja and MSVC, with artifacts written to `build/windows-release/bin/`. Any DLLs produced by CMake should be packaged with the executable.【F:CMakePresets.json†L10-L105】【F:.github/workflows/build-windows.yml†L106-L131】

### macOS
```bash
cmake --preset macos-release
cmake --build --preset macos-release --target otclient
```
The macOS preset builds a Release configuration with Ninja and the platform SDK, producing binaries under `build/macos-release/bin/`.【F:CMakePresets.json†L120-L186】

### Manual configuration (optional)
If you prefer not to use presets, replicate the CI configuration manually:
```bash
cmake -G Ninja -S . -B build/release \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  -DVCPKG_TARGET_TRIPLET=x64-linux
cmake --build build/release --target otclient
```
Adjust the triplet for your platform (`x64-windows-static`, `x64-osx`, etc.). This mirrors the options passed in the Ubuntu CI workflow.【F:.github/workflows/build-ubuntu.yml†L112-L124】

## 5. Assemble a production bundle

After a successful build, gather the executable and runtime assets into a single directory (for example, `dist/otclient`). The release packaging script and Docker runtime image show the minimal set of files that must ship with the binary.【F:Dockerfile†L42-L47】【F:tools/make_snapshot.sh†L205-L225】 Follow these steps:

1. Copy the built `otclient` binary (or `otclient.exe` on Windows) from the `build/<preset>/bin/` directory into your distribution folder.【F:.github/workflows/build-ubuntu.yml†L133-L135】【F:.github/workflows/build-windows.yml†L113-L131】
2. Copy the `data/`, `modules/`, and `mods/` directories from the repository root alongside the executable so Lua scripts and assets are found at runtime.【F:Dockerfile†L42-L45】【F:tools/make_snapshot.sh†L205-L214】
3. Copy `init.lua` and `otclientrc.lua` to the same folder; the client reads these during startup for configuration.【F:Dockerfile†L42-L47】【F:tools/make_snapshot.sh†L215-L223】
4. Optionally include documentation files such as `LICENSE`, `README.md`, and `BUGS` to reproduce the official distribution contents.【F:tools/make_snapshot.sh†L221-L225】
5. Distribute protocol-specific assets (such as `.spr`/`.dat`) separately if required by your server deployment. The snapshot script removes bundled `.spr/.dat` files so you can provide the correct versions for your game build.【F:tools/make_snapshot.sh†L227-L230】

## 6. Docker-based build (optional)

If you prefer a containerized build, the repository ships with a Docker recipe and README instructions:

1. Build the image:
   ```bash
   docker build -t mehah/otclient .
   ```
2. Run the container with access to your X server so the produced binary can be executed immediately:
   ```bash
   xhost +
   docker run -it --rm \
     --env DISPLAY \
     --volume /tmp/.X11-unix:/tmp/.X11-unix \
     --device /dev/dri \
     --device /dev/snd mehah/otclient /bin/bash
   xhost -
   ```
   The Dockerfile reproduces the manual steps above by bootstrapping vcpkg, running CMake, and copying the runtime directories into `/otclient` inside the container.【F:README.md†L470-L499】【F:Dockerfile†L6-L48】

With these steps you can reliably produce and package a production-ready OTClient build across supported desktop platforms.
