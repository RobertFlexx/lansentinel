# building

most people should use the release installer first:

```sh
curl -fsSL https://raw.githubusercontent.com/lansentinel/lansentinel/main/scripts/install.sh | sh
```

building from source is still simple, but pony needs a real native linker toolchain because it produces a native executable.

## requirements

- `ponyc` on your `PATH`, or passed through `PONYC=/path/to/ponyc`.
- a c/c++ compiler and linker runtime for your operating system.
- `make`, unless you call `ponyc` directly.

## linux packages

common package sets:

```sh
# debian / ubuntu
sudo apt install build-essential clang lld

# fedora
sudo dnf install gcc gcc-c++ clang lld compiler-rt

# arch
sudo pacman -S base-devel clang lld compiler-rt
```

package names vary a bit by distro, but the important part is that the system has the startup crt objects and linker runtime files needed for native binaries.

## build commands

```sh
make build
```

with a custom pony compiler path:

```sh
make build PONYC="/path/to/ponyc"
```

without `make`:

```sh
ponyc src -o . --bin-name lansentinel
```

## linker error: crtbeginS.o

if the build gets this far:

```text
Generating
Verifying
Writing ./lansentinel.o
Linking ./lansentinel
```

and then fails with:

```text
could not find compiler-rt CRT objects (crtbeginS.o) in lib paths
```

the lansentinel source compiled. the failure is the final native link step. install your distro's compiler runtime packages, then run `make build` again.

on arch-like systems, start with:

```sh
sudo pacman -S base-devel clang lld compiler-rt
```

on debian/ubuntu-like systems, start with:

```sh
sudo apt install build-essential clang lld
```

on fedora-like systems, start with:

```sh
sudo dnf install gcc gcc-c++ clang lld compiler-rt
```
