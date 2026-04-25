# zwasm

Zig で書かれたスタンドアロンの WebAssembly ランタイムです。CLI ツールとして Wasm モジュールを実行したり、Zig ライブラリとして組み込むことができます。

## 特徴

- **Wasm 3.0 完全対応**: コア仕様 + 批准済み Wasm 3.0 プロポーザル 9 つ (GC、例外処理、末尾呼び出し、関数参照、multi-memory、memory64、branch hinting、extended const、relaxed SIMD)、加えて threads (79 atomics) と wide arithmetic
- **62,263 件のスペックテストに合格**: macOS ARM64 / Linux x86_64 で 100% (Windows x86_64 も CI 対象)
- **4 段階の実行方式**: バイトコード → predecoded IR → register IR → ARM64/x86_64 JIT (NEON/SSE SIMD)、HOT_THRESHOLD=3 で高速にティアアップ
- **WASI Preview 1 + Component Model**: P1 46/46、P2 は component-model アダプタ経由
- **小さなフットプリント**: バイナリ約 1.20 MB (Mac) / 1.56 MB (Linux) (strip 後 ReleaseSafe)、ランタイムメモリ約 3.5 MB
- **ライブラリと CLI**: `zig build` の依存関係として使用、C 共有ライブラリとしてリンク、またはコマンドラインからモジュールを実行
- **WAT サポート**: `.wat` テキスト形式のファイルを直接実行可能

## クイックスタート

```bash
# WebAssembly モジュールを実行
zwasm hello.wasm

# 特定の関数を呼び出す
zwasm math.wasm --invoke add 2 3

# WAT テキストファイルを実行
zwasm program.wat
```

インストール方法については[はじめに](./getting-started.md)を参照してください。
