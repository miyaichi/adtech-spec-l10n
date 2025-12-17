# AdTech Specification Localization (L10n) Tool

IAB Tech Lab等が公開するアドテク関連仕様書（PDF）を日本語に翻訳し、DOCX形式で出力するためのツールです。

## 概要

このツールは、PDFドキュメントから翻訳可能な形式（JSON）への変換、LLMを使った翻訳、そして最終的なDOCX文書の生成を行う、ドキュメント翻訳パイプラインを提供します。

### ワークフロー

```
1. PDF → Text
   raw_pdf/*.pdf → [pdftotext] → intermediate/text/*.txt

2. Text → Alignment JSON
   intermediate/text/*.txt → [pdf_to_alignment.py] → intermediate/alignment/*.json
   + 翻訳用プレースホルダー → translations/*.json (空のjaフィールド)

3. 翻訳（手動）
   translations/*.json → [LLM + system_prompt.md + glossary/] → translations/*.json (jaフィールドを記入)

4. Translated JSON → DOCX
   translations/*.json → [json_to_docx.py] → output/*.docx
```

## プロジェクト構成

```
adtech-spec-l10n/
├── config.yaml                    # 設定ファイル（ドキュメント一覧など）
├── README.md                      # このファイル
├── requirements.txt               # Python依存パッケージ
├── system_prompt.md               # LLM翻訳用のプロンプト
│
├── raw_pdf/                       # 元のPDFファイル
│   ├── Ads.txt-1.1.pdf
│   └── Sellers.json_Final.pdf
│
├── intermediate/                  # 中間ファイル
│   ├── text/                      # PDFから抽出したテキスト
│   │   ├── Ads.txt-1.1.txt
│   │   └── Sellers.json_Final.txt
│   └── alignment/                 # アライメントJSON（原文のみ）
│       ├── Ads.txt-1.1.json
│       └── Sellers.json_Final.json
│
├── translations/                  # 翻訳JSON（原文+訳文）
│   ├── Ads.txt-1.1.json
│   └── Sellers.json_Final.json
│
├── output/                        # 最終成果物（DOCX）
│   ├── Ads.txt-1.1.docx
│   └── Sellers.json_Final.docx
│
├── glossary/                      # 翻訳ルールと用語集
│   ├── rules.md                   # 翻訳ルール
│   └── glossary.md                # 用語集
│
└── scripts/                       # スクリプト
    ├── process_document.sh        # 統合処理スクリプト
    ├── pdf_to_alignment.py        # PDF→アライメントJSON変換
    └── json_to_docx.py            # JSON→DOCX変換
```

## セットアップ

### 1. 依存ツールのインストール

**必須:**
- Python 3.7+
- `pdftotext` (Poppler Utils)

**macOS:**
```bash
brew install poppler
```

**Ubuntu/Debian:**
```bash
sudo apt-get install poppler-utils
```

### 2. Python依存パッケージのインストール

```bash
pip install -r requirements.txt
```

## 使用方法

### クイックスタート

新しいドキュメントを翻訳する場合:

```bash
# 1. PDFをraw_pdf/に配置
cp /path/to/document.pdf raw_pdf/

# 2. config.yamlに登録（エディタで編集）
# documents セクションに追加:
#   - name: "document"
#     pdf_file: "document.pdf"
#     output_title: "Document Title (Japanese Translation)"

# 3. 抽出とアライメントJSON生成
./scripts/process_document.sh document extract

# 4. 翻訳（手動）
#    translations/document.json を開き、LLMに以下を渡す:
#    - system_prompt.md の内容
#    - glossary/ 配下のファイル内容
#    - translations/document.json
#    LLMに "ja" フィールドを翻訳してもらい、保存

# 5. DOCX生成
./scripts/process_document.sh document generate
```

### 詳細な手順

#### Step 1-2: PDF抽出とアライメントJSON生成

```bash
./scripts/process_document.sh <document_name> extract
```

**実行内容:**
1. `raw_pdf/<document_name>.pdf` → `intermediate/text/<document_name>.txt`
2. `intermediate/text/<document_name>.txt` → `intermediate/alignment/<document_name>.json`
3. 翻訳用プレースホルダー作成 → `translations/<document_name>.json`

**例:**
```bash
./scripts/process_document.sh Ads.txt-1.1 extract
```

#### Step 3: 翻訳（手動）

1. `translations/<document_name>.json` を開く
2. LLMに以下を渡す:
   - `system_prompt.md` の内容
   - `glossary/rules.md` の内容
   - `glossary/glossary.md` の内容
   - `translations/<document_name>.json` の全体

3. LLMに「`ja` フィールドを翻訳してください」と依頼
4. 翻訳済みJSONを `translations/<document_name>.json` に保存

**LLMへのプロンプト例:**
```
以下の翻訳ルールと用語集に基づいて、JSONファイルの "ja" フィールドを翻訳してください。

[system_prompt.md の内容]
[glossary/rules.md の内容]
[glossary/glossary.md の内容]

翻訳対象のJSON:
[translations/<document_name>.json の内容]
```

#### Step 4: DOCX生成

```bash
./scripts/process_document.sh <document_name> generate
```

**実行内容:**
- `translations/<document_name>.json` → `output/<document_name>.docx`

**例:**
```bash
./scripts/process_document.sh Ads.txt-1.1 generate
```

### 個別スクリプトの使用

統合スクリプトではなく、個別のスクリプトを使用することもできます。

#### pdf_to_alignment.py

```bash
# 基本
python3 scripts/pdf_to_alignment.py input.txt -o alignment.json

# プレースホルダー翻訳ファイルも作成
python3 scripts/pdf_to_alignment.py input.txt \
    -o intermediate/alignment/doc.json \
    -t translations/doc.json

# ヘルプ
python3 scripts/pdf_to_alignment.py --help
```

#### json_to_docx.py

```bash
# 日本語のみモード
python3 scripts/json_to_docx.py translations/doc.json output/doc.docx

# 対訳モード（英語+日本語）
python3 scripts/json_to_docx.py translations/doc.json output/doc-bilingual.docx --bilingual

# タイトルとフォントを指定
python3 scripts/json_to_docx.py translations/doc.json output/doc.docx \
    --title "Document Title (Japanese Translation)" \
    --font "Hiragino Mincho ProN" \
    --font-size 11

# ヘルプ
python3 scripts/json_to_docx.py --help
```

## 設定ファイル (config.yaml)

### ドキュメントの追加

`config.yaml` の `documents` セクションに追加します:

```yaml
documents:
  - name: "Document-Name"              # ドキュメント識別名（ファイル名のベース）
    pdf_file: "Document-Name.pdf"      # raw_pdf/ 内のPDFファイル名
    output_title: "Document Title (Japanese Translation)"  # DOCX内のタイトル
    description: "Document description"  # 説明（オプション）
```

### ディレクトリ設定

デフォルトのディレクトリ構成を変更する場合は `directories` セクションを編集します:

```yaml
directories:
  raw_pdf: "raw_pdf"
  intermediate_text: "intermediate/text"
  intermediate_alignment: "intermediate/alignment"
  translations: "translations"
  output: "output"
  glossary: "glossary"
```

## トラブルシューティング

### pdftotext が見つからない

```bash
# macOS
brew install poppler

# Ubuntu/Debian
sudo apt-get install poppler-utils
```

### python-docx が見つからない

```bash
pip install python-docx
```

### 翻訳ファイルが空だと言われる

Step 3 の翻訳作業が完了していることを確認してください。`translations/<document_name>.json` の `"ja"` フィールドに翻訳文が入っている必要があります。

### DOCX内のフォントが正しく表示されない

お使いの環境にフォントがインストールされていない可能性があります。`json_to_docx.py` の `--font` オプションで利用可能なフォントを指定してください:

```bash
# macOS
python3 scripts/json_to_docx.py input.json output.docx --font "Hiragino Mincho ProN"

# Windows
python3 scripts/json_to_docx.py input.json output.docx --font "MS Mincho"
```

## 将来の拡張

現在、Step 3（翻訳）は手動で行いますが、将来的には以下の自動化が可能です:

### 1. LLM API との統合

**Claude API / OpenAI API との統合:**
- Step 3（翻訳）の完全自動化
- `system_prompt.md` と `glossary/` を使った自動翻訳
- バッチ処理による複数ドキュメントの一括処理

**実装例:**
```bash
# 自動翻訳モード
./scripts/process_document.sh Ads.txt-1.1 all --auto-translate

# Claude APIを使用
./scripts/process_document.sh document extract
python3 scripts/translate_with_api.py \
    intermediate/alignment/document.json \
    --api claude \
    --output translations/document.json
./scripts/process_document.sh document generate
```

### 2. 翻訳メモリ（TM）の活用

**翻訳メモリとは:**

過去の翻訳（原文と訳文のペア）をデータベースに保存し、新しい翻訳作業で再利用する技術です。

**主なメリット:**
- **一貫性の向上**: 同じ文や類似文は常に同じように翻訳される
- **効率化**: 既に翻訳した文は再翻訳不要
- **コスト削減**: LLM API の呼び出し回数を削減
- **品質向上**: 確定した翻訳を蓄積することで品質が安定

**実装レベル:**

1. **レベル1: 完全一致TM**
   - JSONファイルベースのシンプルなTM
   - 完全に同じ文のみ再利用
   - 実装が容易

2. **レベル2: 類似度検索TM（推奨）**
   - Fuzzy matching による類似文検索
   - 編集距離や類似度スコア（80%以上など）で判定
   - 部分一致も検出して参考情報として提示

3. **レベル3: 意味ベースTM**
   - LLM埋め込み（Embeddings）を使用
   - 意味的に類似した文を検出
   - ベクトルDB（Chroma、FAISS等）で高速検索

**想定されるフォルダ構成:**
```
adtech-spec-l10n/
├── tm/                          # 翻訳メモリ
│   ├── tm_database.json         # TM本体（シンプル版）
│   ├── tm_database.db           # または SQLite
│   ├── term_glossary.json       # 用語レベルのTM
│   └── embeddings/              # 埋め込みベクトル（レベル3）
└── scripts/
    ├── tm_build.py              # 既存翻訳からTMを構築
    ├── tm_search.py             # TM検索
    ├── tm_add.py                # TMに翻訳を追加
    └── translate_with_tm.py     # TM活用翻訳
```

**使用フロー例:**
```bash
# 1. 既存の翻訳からTMを構築
python3 scripts/tm_build.py translations/Ads.txt-1.1.json
python3 scripts/tm_build.py translations/Sellers.json_Final.json

# 2. 新しいドキュメントを翻訳（TM活用）
python3 scripts/translate_with_tm.py \
    intermediate/alignment/new-doc.json \
    --tm tm/tm_database.json \
    --threshold 0.8 \
    --output translations/new-doc.json

# 3. 翻訳結果をTMに追加
python3 scripts/tm_add.py \
    translations/new-doc.json \
    --tm tm/tm_database.json
```

**期待される効果:**

このプロジェクトでは、Ads.txt と Sellers.json は同じ IAB Tech Lab の仕様書であり、以下のような共通表現が多く存在します:
- "The specification defines..." → "本仕様は...を定義する"
- "IAB Technology Laboratory" → "IAB Technology Laboratory"
- "This document is available at..." → "本ドキュメントは...で入手可能である"

TM活用により、2つ目以降のドキュメントでは:
- 翻訳時間を 50-70% 削減
- API呼び出しコストを 40-60% 削減
- 用語の一貫性を 100% 保証

### 3. その他の拡張機能

- **差分翻訳**: 仕様書の新バージョンが出た際、変更箇所のみを再翻訳
- **品質チェック**: 翻訳後の用語統一チェック、形式チェック
- **レビューワークフロー**: 翻訳→レビュー→承認のフロー管理
- **多言語対応**: 日本語以外の言語への翻訳サポート
- **Webインターフェース**: ブラウザベースの翻訳管理UI

これらの機能は、統合CLIツールとして `scripts/process_document.sh` や新規スクリプトに段階的に追加される予定です。

## ライセンス

このツールはMITライセンスの下で公開されています。翻訳対象のドキュメント自体のライセンスについては、各ドキュメントの元のライセンスを参照してください。

## 貢献

バグ報告や機能追加の提案は Issue にてお願いします。
