# dUSD

The Ardana Dollar Stablecoin

## Using the Nix Binary Cache via Cachix

You will need to have Nix installed, with Flakes enabled.

To avoid compiling any output of the flake.nix of this project from source, you can use our Cachix:

1. Get Cachix: `nix shell nixpkgs#cachix`
2. Sign into app.cachix.org with GitHub
3. Generate a personal auth token at https://app.cachix.org/personal-auth-tokens
4. Put that token into this command and run it: `cachix authtoken <TheTokenYouJustCopied>`
5. Run `cachix use private-ardanalabs`.

You can ensure that the Cachix is being used by trying to build one of the outputs and observing that everything is downloaded, and that nothing needs to be compiled from source.


## test-plan & hello world documentation
`./docs/test-plan/test-plan.pdf` documents design decisions, testing, and acceptance criteria for the project.

`./docs/test-plan/hello-world.pdf` documents the hello world application. A simple test project to get you up and running. 

When editing any documents within ./docs/test-plan you can set up a latex pdf rendering feedback loop by running
```
# Or, if you are already inside nix-shell, run: `dusd-feedback-loop`
nix run .#feedback-loop
```

## Development workflow

### Dev shells

The onchain and offchain code have different dependencies, thus different dev shells. To launch a shell for onchain dev, run:

```
nix develop .#onchain
```

For offchain, run:

```
nix develop .#offchain
```

### Ghcid

In the nix shell, run `dusd-<TAB>` to see available commands, and select the appropriate ghcid configuration. For example, running `dusd-offchain-ghcid-lib` will run Ghcid on the offchain library component.

### Formatting

To auto-format the project tree, run:

```sh-session
nix run .#format
```
