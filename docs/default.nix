{ inputs, system, pkgs }:

{
  packages = {
    build-docs = pkgs.stdenv.mkDerivation {
      name = "build-docs";
      src = ./.;
      buildInputs = with pkgs; [ (texlive.combine { inherit (texlive) scheme-basic latexmk todonotes metafont; }) ];
      doCheck = false;
      buildPhase = ''
        HOME=$TMP latexmk -output-directory="tmp" -pdf ./*.tex
        mkdir $out -p
        cp tmp/*.pdf $out
      '';
      installPhase = ''
        ls -lah
      '';
    };
  };

  apps = {
    feedback-loop = {
      type = "app";
      program = pkgs.writeShellApplication
        {
          name = "${inputs.self.projectName}-feedback-loop";
          runtimeInputs = [ pkgs.entr ];
          # FIXME: Running 'nix build' inside an app is rather alow. This should
          # just directly call the same command as the build derivation above
          # (ie. latexmk).
          text = ''
            find docs -name "*.tex" | entr nix build .#build-docs
          '';
        } + "/bin/${inputs.self.projectName}-feedback-loop";
    };
  };
}
