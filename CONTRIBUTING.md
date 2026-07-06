# contributing

lansentinel is intentionally small, pony-first, and pretty direct. the best contribution is usually a focused fix or feature that keeps the tool honest about what it can and cannot know about a network.

## development setup

build the binary:

```sh
make build
```

run smoke tests:

```sh
scripts/smoke-test.sh
```

if `ponyc` is not on your `PATH`, pass it directly:

```sh
make build PONYC="/path/to/ponyc"
PONYC="/path/to/ponyc" scripts/smoke-test.sh
```

you also need a native linker toolchain. if the build compiles and then fails at `Linking ./lansentinel` with `crtbeginS.o` or compiler-rt errors, install your distro's normal build tools, such as `build-essential`, `base-devel`, or `gcc` plus `compiler-rt`.

## project shape

- `src/` contains the pony application code.
- `examples/` contains runnable examples and a sample config file.
- `docs/` contains focused user docs that support the readme.
- `scripts/` contains smoke test, package, and local install helpers.
- `dist/` is generated package output from `scripts/package.sh`.

## contribution guidelines

- keep the core app entirely in pony.
- preserve the actor-based watcher, supervisor, scanner, and renderer style.
- prefer small compile-safe changes over broad rewrites.
- do not fake networking behavior in output or tests.
- keep cli errors friendly and specific enough to fix the command.
- document limitations honestly, especially around discovery accuracy.
- keep json, csv, and prometheus output free of terminal decoration.
- do not add ffi without a strong documented reason and project agreement.
- do not add shell-outs to common network tools just to make discovery look smarter.

## useful checks

these commands are good quick checks before opening a pull request:

```sh
./lansentinel --explain-scan
./lansentinel --scan 127.0.0.0/30 --ports 1 --json
./lansentinel --once --json localhost:1
./lansentinel --once --fail-fast localhost:1
```

for documentation changes, make sure examples still match the cli names and still feel useful to someone reading about the tool for the first time.

## pull request notes

- describe the user-visible change first.
- include the commands you ran.
- call out any network assumptions in tests or examples.
- keep generated files separate from source changes when possible, because package artifacts can be noisy.
