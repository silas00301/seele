# Voxtype: batch Parakeet and streaming follow-up

## Active configuration

[SIL-65](https://linear.app/silas0301/issue/SIL-65) now uses batch Parakeet v3
for German, English and mixed German/English speech, as approved on 2026-09-19.
Japanese is deferred. `SUPER+D` starts recording; pressing it again stops
recording and types the final transcript. No text is emitted while recording.

`modules/features/programs/voxtype.nix` retains the existing user service,
audio defaults (16 kHz, 60-second maximum), type output, clipboard fallback,
modifier-release handling and disabled Voxtype OSD. Seele Shell still consumes
the native status/audio socket; the integration captures no additional audio.
The feature is imported by the `nerv` Home Manager profile because its CUDA
package is specific to that NVIDIA host.

`modules/packages/voxtype.nix` adapts upstream `onnx-cuda`, pinned through the
Voxtype input with the parent's nixpkgs. The revision includes the Nix hashes
for its OpenVINO Git dependencies, missing from v1.0.1's flake. The adapter adds
`onnx-load-dynamic` so the CUDA probe accepts the Nix-provided ONNX Runtime
rather than enforcing a bundled runtime's CUDA major version. Its wrapper
makes `cuda_cudart` and `/run/opengl-driver/lib` discoverable by `dlopen`.
Upstream supplies the CUDA-enabled ONNX Runtime and typing/clipboard tools.

The immutable FP32 model directory contains exactly the batch loader's encoder,
external encoder weights, joint decoder and vocabulary. Each file is separately
hashed and fetched from [export revision
`8f23f0c03c8761650bdb5b40aaf3e40d2c15f1ce`](https://huggingface.co/istupakov/parakeet-tdt-0.6b-v3-onnx/tree/8f23f0c03c8761650bdb5b40aaf3e40d2c15f1ce).
The loader uses built-in preprocessing, so no streaming tokenizer or additional
preprocessor graph is needed. No mutable model download or setup command runs
at service start. ONNX graphs and external weights are copied together so their
relative references resolve within the model directory.

## Streaming follow-up

[SIL-66](https://linear.app/silas0301/issue/SIL-66) owns the future switch to live
streaming and assessment of Japanese support. The following source investigation
from 2026-09-19 explains why `parakeet.streaming` remains explicitly false.

## Evidence

Upstream's latest release was [v1.0.1](https://github.com/peteonrails/voxtype/releases/tag/v1.0.1)
(`dda37ca72b71294d08b0c5bb49c5b24ca590d847`). The investigation inspected the
newer `dev` revision `320a737e5d3c8662e0ec7de95f75407baa784d82`, rather than
assuming the release's limitations still applied.

- The [model registry](https://github.com/peteonrails/voxtype/blob/320a737e5d3c8662e0ec7de95f75407baa784d82/src/setup/model.rs#L103-L218)
  marks both full-precision and INT8 multilingual TDT v3 models as incompatible
  with streaming. Its only compatible entry is `parakeet-unified-en-0.6b`,
  explicitly English-only.
- The [streaming constructor](https://github.com/peteonrails/voxtype/blob/320a737e5d3c8662e0ec7de95f75407baa784d82/src/transcribe/parakeet_streaming.rs#L58-L96)
  rejects known incompatible models. It requires both `tokenizer.model` and a
  decoder graph suited to the cache-aware inference loop. The source documents
  missing-tokenizer and ONNX Gather shape failures for the ordinary export.
  A custom directory bypasses the registry check with a warning; that is not
  evidence that its graphs work. Adding a tokenizer or renaming files does not
  establish compatibility. No verified multilingual custom export was identified
  in this investigation; no model inference was run.
- The [daemon event pump](https://github.com/peteonrails/voxtype/blob/320a737e5d3c8662e0ec7de95f75407baa784d82/src/daemon.rs#L4179-L4241)
  sends partial transcripts through `type_partial_delta` for cursor output.
  The transcriber's introductory comment about final-only typing is stale;
  cursor output is not an additional source-level blocker at this revision.
- NVIDIA's [model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3/blob/541d1f99c6b0c3cd0b11a95167540bb8edefd82b/README.md)
  lists 25 European languages, including German and English, but not Japanese.
  A streaming export alone cannot establish the issue's Japanese and mixed
  German/English/Japanese acceptance criteria.
- The [upstream flake](https://github.com/peteonrails/voxtype/blob/320a737e5d3c8662e0ec7de95f75407baa784d82/flake.nix#L377-L388)
  exposes `onnx-cuda`; `parakeet-cuda` remains an alias. Package availability
  does not establish model compatibility or actual CUDA execution.

## Resume conditions

1. Identify and pin a multilingual export proven to load, process repeated
   chunks, flush and reset through Voxtype's `ParakeetUnified` path. Provision
   its exact graph, external weight and tokenizer files in an immutable Nix
   store directory, preferring full precision. Record hashes and provenance.
2. Resolve Japanese support explicitly. The named TDT v3 model does not meet
   that requirement; a different model/backend or revised scope needs an
   explicit decision. Do not substitute the English-only streaming model or
   batch transcription as completion.
3. Only after that gate passes, enable streaming in the existing module.
   Preserve `SUPER+D` toggle, audio settings, type output, clipboard fallback,
   modifier-release handling, disabled OSD, service and native shell socket.
4. On `nerv`, prove CUDA execution on the RTX 5070 Ti, incremental cursor output
   in browser and terminal/editor fields, toggle reliability, the existing
   waveform, offline operation, all agreed languages and mixed speech. Include
   NixOS, Home Manager, Hyprland, Quickshell, Kotlin, Gradle, Tailscale and Seele
   in speech samples. Then complete flake checks and the host build.

## Validation boundary

Source/model-card inspection checked the configuration and loader contracts.
`nix fmt` passed, the Voxtype package evaluated and built, and the complete
`nerv` system closure built without activation. Those builds fetched and
verified the pinned source and model hashes and compiled ONNX Runtime with
native SM120 CUDA code for this host's RTX 5070 Ti.

Model inference, recognition quality and runtime GPU execution remain
unverified. A successful CUDA build does not prove that ONNX Runtime selects
the CUDA provider for this model rather than falling back to the CPU provider.

After an explicitly requested activation on `nerv`, check
`systemctl --user status voxtype` and `journalctl --user -u voxtype -b` for the
pinned TDT model and CUDA provider selection. A CPU-fallback warning is a failed
CUDA check. Confirm GPU activity/VRAM during inference with `nvidia-smi`; a build
with CUDA support or an initialization message alone is not runtime proof.
Exercise toggle start/stop repeatedly with the native waveform visible, then
verify final output in browser and terminal/editor fields, clipboard fallback,
German/English/mixed speech and the technical vocabulary listed above. Repeat
with networking disabled after provisioning. These native-host checks have not
been performed in the authoring environment.
