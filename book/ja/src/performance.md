# パフォーマンス

## 実行ティア

zwasm は階層型実行を採用しています:

1. **インタープリタ**: すべての関数はレジスタ IR として開始され、ディスパッチループで実行されます。起動が速く、コンパイルのオーバーヘッドがありません。
2. **JIT (ARM64/x86_64)**: ホットな関数は、呼び出し回数またはバックエッジ回数がしきい値を超えるとネイティブコードにコンパイルされます。

### JIT が発動する条件

- **呼び出し / バックエッジしきい値**: `HOT_THRESHOLD = 3` (W38 で 10 から引き下げ)。関数は 3 回呼び出されるか、ホットループ内でバックエッジを 3 回踏むと JIT に昇格します。
- **バックエッジカウント**: 呼び出しのしきい値を待たずにホットループを検出します。ループ反復は個別にカウント。

JIT コンパイル後は、その関数の以降の呼び出しはレジスタ IR インタープリタをバイパスし、ネイティブマシンコードを直接実行します。

## バイナリサイズとメモリ

| 指標                                | 値                                |
|-------------------------------------|-----------------------------------|
| バイナリサイズ (ReleaseSafe, strip 後) | 約 1.20 MB (Mac) / 1.56 MB (Linux) |
| CI 上限 (strip 後)                  | 1.60 MB                           |
| ランタイムメモリ (fib ベンチマーク) | 約 3.5 MB RSS                     |
| wasmtime バイナリ（比較用）          | 約 56 MB                          |

zwasm は Linux で wasmtime の約 1/35、Mac で約 1/47 のサイズです。

## ベンチマーク結果

Apple M4 Pro 上で zwasm を wasmtime 41.0.1、Bun 1.3.8、Node v24.13.0 と比較した代表的なベンチマーク。
29 個のうち過半数で wasmtime と同等以上、計算重視の長時間ベンチ (`st_fib2` など) は依然 Cranelift AOT に劣位。

| ベンチマーク | zwasm | wasmtime | Bun | Node |
|-------------|------:|---------:|----:|-----:|
| nqueens(8) | 2 ms | 5 ms | 14 ms | 23 ms |
| nbody(1M) | 22 ms | 22 ms | 32 ms | 36 ms |
| gcd(12K,67K) | 2 ms | 5 ms | 14 ms | 23 ms |
| tak(24,16,8) | 5 ms | 9 ms | 17 ms | 29 ms |
| sieve(1M) | 5 ms | 7 ms | 17 ms | 29 ms |
| fib(35) | 46 ms | 51 ms | 36 ms | 52 ms |
| st_fib2 | 900 ms | 674 ms | 353 ms | 389 ms |

メモリ使用量は wasmtime の 3〜4 分の 1、Bun/Node の 8〜10 分の 1 です。

全結果（29 ベンチマーク）: `bench/runtime_comparison.yaml`

### SIMD パフォーマンス

SIMD (v128) 命令はネイティブの NEON (ARM64, 253/256 命令) および SSE (x86_64, 244/256 命令) に
JIT コンパイルされます。v128 値は連続レジスタ格納 (W37) を採用し、Q-cache (Q16–Q31 / XMM6–XMM15、W43, W44) で
ホットなベクトルをレジスタに保持します。

| ベンチマーク              | zwasm スカラー | zwasm SIMD | wasmtime SIMD | スカラー→SIMD |
|---------------------------|---------------:|-----------:|--------------:|--------------:|
| image_blend (128x128)     | 73 ms          | 16 ms      | 12 ms         | **4.7×**      |
| matrix_mul (16x16)        | 10 ms          | 6 ms       | 8 ms          | **1.6×**      |
| byte_search (64KB)        | 52 ms          | 43 ms      | 5 ms          | 1.2×          |
| dot_product (4096)        | 142 ms         | 190 ms     | 15 ms         | 0.75×         |

`matrix_mul` は wasmtime を上回り、`image_blend` は 1.4 倍差で互角圏内。
`byte_search` と `dot_product` は wasmtime に劣位ですが、これは `i16x8.replace_lane` や `v128.load` の多い
コンパイラ生成コード (C `-msimd128`) のパターンが主因です。次の改善レバーとして
ループヘッダでの Q-cache eviction 抑制 (W45) を追跡しています。

全データ: `bench/simd_comparison.yaml`

## ベンチマーク手法

すべての測定は [hyperfine](https://github.com/sharkdp/hyperfine) を使用し、ReleaseSafe ビルドで行っています:

```bash
# クイックチェック（1回実行、ウォームアップなし）
bash bench/run_bench.sh --quick

# 完全な測定（5回実行、3回ウォームアップ）
bash bench/run_bench.sh

# 履歴に記録
bash bench/record.sh --id="X" --reason="description"
```

### ベンチマークレイヤー

| レイヤー | 数 | 説明 |
|---------|-----|------|
| WAT micro  | 5  | 手書き: fib, tak, sieve, nbody, nqueens                      |
| TinyGo     | 11 | TinyGo コンパイラ出力: 同じアルゴリズム + 文字列操作         |
| Shootout   | 5  | Sightglass shootout スイート (WASI)                          |
| Real-world | 6  | Rust, C, C++ を Wasm にコンパイル (行列、数学、文字列、ソート) |
| GC         | 2  | GC プロポーザル: 構造体アロケーション、木の走査              |
| SIMD       | 10 | WAT マイクロ (4) + C -msimd128 実世界 (5)、スカラー/SIMD    |

### CI によるリグレッション検出

PR は自動的にパフォーマンスリグレッションがチェックされます:
- 12 の代表的なベンチマーク（uncached 6 + cached 6）がベースブランチと PR ブランチの両方で実行されます
- いずれかのベンチマークが 20% 以上リグレッションした場合、失敗となります
- 同一ランナーにより公平な比較が保証されます

## パフォーマンスのヒント

- **ReleaseSafe**: 本番環境では必ず使用してください。Debug は5〜10倍遅くなります。
- **ホットな関数**: 頻繁に呼び出される関数は自動的に JIT コンパイルされます。
- **Fuel 制限**: `--fuel` は命令ごとにオーバーヘッドが加わります。信頼できないコードにのみ使用してください。
- **メモリ**: リニアメモリを持つ Wasm モジュールはガードページを割り当てます。初期 RSS はモジュールサイズに関係なく約 3.5 MB です。
