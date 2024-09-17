# Hello Cardano Template

A template for starting an application on Cardano.

## Using the Nix Binary Cache via Cachix

You will need to have Nix installed, with Flakes enabled.
This will allow you to avoid compiling any output of the flake.nix of this project from source.

If you have Nix installed on a Linux system in a multi-user fashion (the default):

1. Add the Cachix to your `/etc/nix/nix.conf`:
  ```
  substituters = https://private-ardanalabs.cachix.org
  trusted-public-keys = private-ardanalabs.cachix.org-1:BukERsr5ezLsqNT1T7zlS7i1+5YHsuxNTdvcgaI7I6Q=
  ```
2. Add the path to your netrc file in `/etc/nix/nix.conf`:
  ```
  netrc-file = /etc/nix/netrc
  ```
3. Add your Cachix auth token to the netrc file:
  ```
  machine private-ardanalabs.cachix.org password <your cachix auth token>
  ```
  you can get your Cachix auth token by creating one at https://app.cachix.org/personal-auth-tokens.

If you have Nix installed in a single-user fashion:

1. Get Cachix: `nix shell nixpkgs#cachix`
2. Sign into app.cachix.org with GitHub
3. Generate a personal auth token at https://app.cachix.org/personal-auth-tokens
4. Put that token into this command and run it: `cachix authtoken <TheTokenYouJustCopied>`
5. Run `cachix use private-ardanalabs`.

If you want to add Cachix in a declarative way (aka you are using NixOS):

1. In your `configuration.nix`, add this code to add the cache:
  ```nix
  {
    # if you are on nixpkgs stable channel / branch, this will probably work for you
    nix = {
      binaryCaches = ["https://private-ardanalabs.cachix.org"];
      binaryCachePublicKeys = ["private-ardanalabs.cachix.org-1:BukERsr5ezLsqNT1T7zlS7i1+5YHsuxNTdvcgaI7I6Q="];
    };
    # if you get a deprecated warning, or you are on nixpkgs unstable channel / branch, this should work
    nix.settings = {
      substituters = ["https://private-ardanalabs.cachix.org"];
      trusted-public-keys = ["private-ardanalabs.cachix.org-1:BukERsr5ezLsqNT1T7zlS7i1+5YHsuxNTdvcgaI7I6Q="];
    };
  }
  ```
2. To enable authenticating with the Cachix, you need to point Nix to a netrc file:
  ```nix
  {
    nix.extraConfig = ''
      netrc-file = <path to netrc file>
    '';
  }
  ```
  this netrc file can be encrypted with [age] and be used with [agenix], so you can store it securely in wherever.
3. The netrc file should contain this:
  ```
  machine private-ardanalabs.cachix.org password <your cachix auth token>
  ```
  you can get your Cachix auth token by creating one at https://app.cachix.org/personal-auth-tokens.

You can ensure that the Cachix is being used by trying to build one of the outputs and observing that everything is downloaded, and that nothing needs to be compiled from source.

## test-plan & hello world documentation
`./docs/test-plan/test-plan.pdf` documents design decisions, testing, and acceptance criteria for the project.

`./docs/test-plan/hello-world.pdf` documents the hello world application. A simple test project to get you up and running. 

When editing any documents within ./docs/test-plan you can set up a latex pdf rendering feedback loop by running
```
nix run .#docs:feedback-loop
```

## Development workflow

### Dev shells

The onchain and offchain code have different dependencies, thus different dev shells. To launch a shell for onchain dev, run:

```
nix develop .#onchain
```

For various offchain components, run:

```
nix develop .#offchain:component
```
for example, for `hello-world-cli` this would be `nix develop .#offchain:hello-world-cli`.

### Formatting

To auto-format the project tree, run:

```sh-session
nix run .#format
```

If you are in nix-shell already, you can also just run `treefmt`.

### Running checks locally

Although CI is run on every attribute of the `flake.nix` upon every commit of
every branch, you may also some of the same checks locally as follows:

```sh-session
# -L is for displaying full logs, which includes test output.
nix flake check -L
```

### Making a new package (flake module)

Every project is imported by the top-level default.nix in each folder. For
example, `offchain/default.nix` imports the flake-module.nix for multiple
projects.

Each project in this repository should have a `flake-module.nix` based on the
following template, at its root. You can run `nix flake init -t .`
anywhere in this repository, and a new `flake-module.nix` with the following
skeleton template will be created in your current directory.

```
{ self, ... }:
{
  perSystem = { config, self', inputs', system, ... }: {
  };
  flake = {
  };
}
```

This is part of the
[flake-parts](https://github.com/hercules-ci/flake-parts)
framework. Each of these `flake-module.nix` files can be thought of as a
subflake. They can also be thought of as a `default.nix` similar to what you see
in Nixpkgs next to every package. The real name for this, though, is a "flake
module".

`perSystem` is where flake attributes like `packages` or `apps` which need a
system argument like `x86_64-linux` may go.

`flake` is where any flake attribute can go, in the event of any confusion with
the framework. Anything that doesn't require a system like `x86_64-linux` goes
here.

`inputs'` and `self'` have the `system` abstracted away. For example, the
following expressions are equivalent to eachother:

- `inputs'.nixpkgs.legacyPackages`
- `self.inputs.nixpkgs.legacyPackages.x86_64-linux`

Another example of equivalence is as follows:

-  `self'.packages.hello`
-  `self.packages.x86_64-linux.hello`

[age]: https://github.com/FiloSottile/age "age"
[agenix]: https://github.com/ryantm/agenix "agenix"

## Built by

<img atl="Platonic.Systems Logo" src="https://ardana.org/assets/logos/platonic-systems.svg" height="30px">

<img atl="Ardana Logo" src="https://ardana.org/assets/logo_text.png" height="30px">

