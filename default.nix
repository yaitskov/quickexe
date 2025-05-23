{ system ? builtins.currentSystem or "x86_64-linux"
, ghc ? "ghc9101"
}:

let
  nix = import ./nix;
  pkgs = nix.pkgSetForSystem system {
    config = {
      allowBroken = true;
      allowUnfree = true;
    };
  };
  inherit (pkgs) lib;
  hsPkgSetOverlay = pkgs.callPackage ./nix/haskell/overlay.nix {
    inherit (nix) sources;
  };

  sources = [
    "^src.*$"
    "^test.*$"
    "^.*\\.cabal$"
  ];

  base = hsPkgs.callCabal2nix "th-process" (lib.sourceByRegex ./. sources) { };
  th-process-overlay = _hf: _hp: { th-process = base; };
  baseHaskellPkgs = pkgs.haskell.packages.${ghc};
  hsOverlays = [ hsPkgSetOverlay th-process-overlay ];
  hsPkgs = baseHaskellPkgs.override (old: {
    overrides =
      builtins.foldl' pkgs.lib.composeExtensions (old.overrides or (_: _: { }))
      hsOverlays;
  });

  hls = pkgs.haskell.lib.overrideCabal hsPkgs.haskell-language-server
    (_: { enableSharedExecutables = true; });

  shell = hsPkgs.shellFor {
    packages = p: [ p.th-process ];
    nativeBuildInputs = (with pkgs; [
      cabal-install
      ghcid
      hlint
      niv
      z3
    ]) ++ [ hls ];
    shellHook = ''
      export PS1='$ '
      echo $(dirname $(dirname $(which ghc)))/share/doc > .haddock-ref
    '';
  };

  th-process = hsPkgs.th-process;
in {
  inherit hsPkgs;
  inherit ghc;
  inherit pkgs;
  inherit shell;
  inherit th-process;
}
