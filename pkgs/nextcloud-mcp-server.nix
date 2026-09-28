# cbcoutinho/nextcloud-mcp-server, built from upstream's uv.lock with uv2nix.
#
# nixpkgs' python3Packages can't satisfy it (mcp>=2.1, pymupdf==1.28.2,
# starlette<1, pythonvcard4), so the lock is the source of truth: every
# dependency is the exact wheel upstream tests against. Bump the version by
# changing the `nextcloud-mcp-server` flake input's tag.
{
  lib,
  pkgs,
  src,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}:
let
  inherit (pkgs) python3;

  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src; };

  # Prebuilt manylinux wheels (grpcio, pymupdf, numpy, ...) link against
  # libstdc++/zlib from the FHS; patch them against the Nix store instead.
  patchWheels =
    final: prev:
    lib.mapAttrs (
      _: drv:
      if drv ? overrideAttrs && lib.hasSuffix ".whl" (toString (drv.src or "")) then
        drv.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.autoPatchelfHook ];
          buildInputs = (old.buildInputs or [ ]) ++ [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ];
          # Optional GPU/accelerator libs some wheels probe for at runtime.
          autoPatchelfIgnoreMissingDeps = true;
        })
      else
        drv
    ) prev;

  # caldav pulls in urllib3-future, which intentionally ships its own
  # `urllib3/` package on top of the real one. pip/uv let it overwrite
  # urllib3's files; the Nix venv refuses the collision instead, so drop
  # urllib3's module and keep only its metadata, the same end state as a
  # `uvx` install.
  urllib3Future = _final: prev: {
    urllib3 = prev.urllib3.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        rm -r $out/${python3.sitePackages}/urllib3
      '';
    });
  };

  pythonSet = (pkgs.callPackage pyproject-nix.build.packages { python = python3; }).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
      patchWheels
      urllib3Future
    ]
  );

  venv = pythonSet.mkVirtualEnv "nextcloud-mcp-server-env" workspace.deps.default;
in
pkgs.runCommand "nextcloud-mcp-server-${pythonSet.nextcloud-mcp-server.version}"
  {
    meta = {
      description = "MCP server for Nextcloud (notes, calendar, contacts, files, deck, ...)";
      homepage = "https://github.com/cbcoutinho/nextcloud-mcp-server";
      license = lib.licenses.agpl3Only;
      mainProgram = "nextcloud-mcp-server";
    };
  }
  ''
    mkdir -p $out/bin
    ln -s ${venv}/bin/nextcloud-mcp-server $out/bin/nextcloud-mcp-server
  ''
