{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      upstream = inputs.voxtype.packages.${system};
      # The package dynamically loads Nix's ORT. Tell Voxtype's CUDA probe too,
      # so it does not enforce the bundled ORT's default CUDA major version.
      unwrapped = upstream.voxtype-onnx-cuda-unwrapped.overrideAttrs (old: {
        cargoBuildFeatures = old.cargoBuildFeatures ++ [ "onnx-load-dynamic" ];
        cargoCheckFeatures = old.cargoCheckFeatures ++ [ "onnx-load-dynamic" ];
      });
    in
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        voxtype = upstream.onnx-cuda.overrideAttrs (old: {
          paths = [ unwrapped ];
          postBuild = old.postBuild + ''
            # Voxtype probes libcudart with dlopen before creating an ORT
            # session. Its direct dependencies do not supply that search path.
            wrapProgram "$out/bin/voxtype" \
              --prefix LD_LIBRARY_PATH : "${
                lib.makeLibraryPath [ pkgs.cudaPackages.cuda_cudart ]
              }:/run/opengl-driver/lib"
          '';
        });
      };
    };
}
