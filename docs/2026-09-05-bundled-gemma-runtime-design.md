# Bundled Gemma runtime design

## Goal

Make Gemma 3 270M available to future `retro-ai` game code without changing current gameplay, UI, scoring, or stage behavior. The project must remain offline at runtime and deploy as one self-contained Arduino App Lab game package.

## Chosen approach

Run a bundled `llama-server` child process and expose it through a small typed GDScript client. Keep the model and native runtime outside the Godot `.pck`, but inside the final game ZIP.

This keeps native inference failures outside the Summer process and uses a stable local HTTP boundary. An in-process GDExtension would have less process overhead but would add ABI, cross-compilation, and crash-isolation risks. A board-wide service would avoid repeated model uploads, but it would no longer be part of the game package and the current Uno Q installer does not manage it.

## Package layout

The exported archive contains the game executable and `.pck` at its root, with the model, manifest, attribution, Linux ARM64 `llama-server`, and its shared libraries under `llm/`.

Native tools and weights live in `vendor/llm` while developing. A packaging script appends them to a freshly exported ZIP. They do not enter the `.pck`.

## GDScript API

The reusable `LlmService` node exposes:

```gdscript
signal service_ready
signal failed(message: String)

func start() -> Error
func is_ready() -> bool
func generate(prompt: String, max_tokens: int = 48) -> String
func stop() -> void
```

The service is not added to `main.tscn`, registered as an autoload, or called by gameplay. Future game code can instantiate it explicitly.

## Runtime and failure handling

The service runs CPU inference with four threads, a 1,024-token context, and a single request slot. It binds only to `127.0.0.1` and never downloads files at runtime. Missing assets, occupied ports, startup failures, timeouts, malformed responses, and shutdown are handled explicitly.

## Non-goals

- No prompts from gameplay events.
- No generated text in the UI.
- No changes to game rules or deterministic tests.
- No model fine-tuning or hosted fallback.
- No modifications to `/Users/j/summer-uno-q/board/`.
