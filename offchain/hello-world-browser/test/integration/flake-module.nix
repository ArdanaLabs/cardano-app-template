# test for dUSD Hello World Browser
{ self, ... }:
{
  perSystem = { config, self', inputs', system, ... }:
    let
      # dusd-lib contains helper functions for dealing with haskell.nix. From it,
      # we inherit fixHaskellDotNix
      dusd-lib = config.dusd-lib;
      inherit (dusd-lib.haskell) fixHaskellDotNix;
      # realNixpkgs is required to get chromium and selenium from
      # cache.nixos.org rather than the bloated Haskell.nix Nixpkgs.
      realNixpkgs = inputs'.nixpkgs.legacyPackages;
      # A flake-module in nix/flake-modules/haskell.nix defines haskell-nix
      # packages once, so we can reuse it here, it's more performant.
      pkgs = config.haskell-nix.pkgs;

      # runtime dependencies required for the integration test.
      integrationTestRuntimeDeps = with realNixpkgs; [
        chromedriver
        chromium
        selenium-server-standalone
      ];

      project = pkgs.haskell-nix.cabalProject {
        name = "hello-world-browser-test";

        src = pkgs.runCommand "hello-world-browser-test" { } ''
          cp -rT ${./.} $out
          cp ${./Nami.crx} Nami.crx
        '';

        compiler-nix-name = "ghc8107";
        sha256map = import ./sha256map;

        modules = [{
          packages = {
            hello-world-browser-test.components.tests.integration =
              let
                fontconfigFile =
                  with realNixpkgs;
                  makeFontsConf {
                    fontDirectories = [ twitter-color-emoji roboto ];
                  };
                pathEnv = realNixpkgs.lib.makeBinPath integrationTestRuntimeDeps;
              in
              {
                pkgconfig = [ [ realNixpkgs.makeWrapper ] ];
                postInstall = with realNixpkgs; ''
                  wrapProgram $out/bin/integration \
                    --set FONTCONFIG_FILE ${fontconfigFile} \
                    --set HELLO_WORLD_BROWSER_INDEX ${self'.packages."offchain:hello-world-browser:keyWallet"} \
                    --prefix PATH : "${pathEnv}"
                '';
              };
          };
        }];

        # This is used by `nix develop .` to open a shell for use with
        # `cabal`, `hlint` and `haskell-language-server`
        shell = {
          tools = {
            cabal = { };
            hlint = { };
            haskell-language-server = { };
          };
          buildInputs = integrationTestRuntimeDeps;
        };
      };

      haskellNixFlake =
        fixHaskellDotNix (project.flake { })
          [ ./hello-world-browser-test.cabal ];
      integrationTestName = "hello-world-browser-test:test:integration";
    in
    {
      apps = {
        "offchain:hello-world-browser:test" =
          dusd-lib.mkApp
            (
              pkgs.writeShellApplication
                {
                  name = "run-hello-world-browser-tests";
                  runtimeInputs = [ pkgs.nix ];
                  text = ''
                    nix \
                      --extra-experimental-features 'nix-command flakes' \
                      --option sandbox false build --keep-failed -L \
                      ${self}#checks.\"${system}\".\"${integrationTestName}\".passthru.originalDerivation
                    cat result/test-stdout
                  '';
                }
            );
      };
      checks = haskellNixFlake.checks // {
        # skip tests that require ctl-runtime
        ${integrationTestName} =
          haskellNixFlake.checks.${integrationTestName}.overrideAttrs
            (old: {
              NO_RUNTIME = "TRUE";
              passthru = (old.passthru or { }) // {
                originalDerivation = haskellNixFlake.checks.${integrationTestName};
              };
            });
      };
      devShells."offchain:hello-world-browser:test" = haskellNixFlake.devShell;
      packages =
        # we don't need to have the test also in packages, we have it in checks
        builtins.removeAttrs haskellNixFlake.packages [ integrationTestName ];
    };
  flake = { };
}
