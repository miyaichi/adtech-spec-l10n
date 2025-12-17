#!/bin/bash
# Document Translation Processing Script
#
# Usage: ./process_document.sh <document_name> [step]
#
# Steps:
#   extract  - Step 1-2: PDF → Text → Alignment JSON (翻訳プレースホルダー作成含む)
#   generate - Step 4: Translated JSON → DOCX
#   all      - 全ステップ実行（Step 3は手動のため、extract と generate を順次実行）
#
# Example:
#   ./process_document.sh Ads.txt-1.1 extract
#   ./process_document.sh Ads.txt-1.1 generate
#   ./process_document.sh Ads.txt-1.1 all

set -e  # エラーで停止

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 設定ファイルのパス
CONFIG_FILE="$PROJECT_ROOT/config.yaml"

# 引数チェック
if [ $# -lt 1 ]; then
    echo "Usage: $0 <document_name> [step]"
    echo ""
    echo "Available steps:"
    echo "  extract  - PDF抽出とアライメントJSON生成"
    echo "  generate - DOCX生成"
    echo "  all      - extract + generate (デフォルト)"
    echo ""
    echo "Example:"
    echo "  $0 Ads.txt-1.1"
    echo "  $0 Ads.txt-1.1 extract"
    echo "  $0 Sellers.json_Final generate"
    exit 1
fi

DOC_NAME="$1"
STEP="${2:-all}"

# YAMLから設定を読み込む（簡易的にgrepとsedで抽出）
# 注: 本格的なYAMLパーサーを使う場合は yq などを使用
get_config_value() {
    local key="$1"
    local default="$2"
    if [ -f "$CONFIG_FILE" ]; then
        grep "^  $key:" "$CONFIG_FILE" | sed 's/.*: *"\(.*\)".*/\1/' | head -1
    else
        echo "$default"
    fi
}

# ディレクトリ設定（config.yamlから読み込み、なければデフォルト値）
RAW_PDF_DIR="${RAW_PDF_DIR:-$(get_config_value "raw_pdf" "raw_pdf")}"
INTERMEDIATE_TEXT_DIR="${INTERMEDIATE_TEXT_DIR:-$(get_config_value "intermediate_text" "intermediate/text")}"
INTERMEDIATE_ALIGNMENT_DIR="${INTERMEDIATE_ALIGNMENT_DIR:-$(get_config_value "intermediate_alignment" "intermediate/alignment")}"
TRANSLATIONS_DIR="${TRANSLATIONS_DIR:-$(get_config_value "translations" "translations")}"
OUTPUT_DIR="${OUTPUT_DIR:-$(get_config_value "output" "output")}"

# ファイルパスの構築
PDF_FILE=""
OUTPUT_TITLE=""

# config.yamlからPDFファイル名とタイトルを取得
if [ -f "$CONFIG_FILE" ]; then
    # documentsセクションから該当するドキュメントを探す
    in_doc_section=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"?${DOC_NAME}\"? ]]; then
            in_doc_section=true
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]] && [ "$in_doc_section" = true ]; then
            in_doc_section=false
        fi

        if [ "$in_doc_section" = true ]; then
            if [[ "$line" =~ ^[[:space:]]*pdf_file:[[:space:]]*\"?([^\"]+)\"? ]]; then
                PDF_FILE="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*output_title:[[:space:]]*\"(.+)\" ]]; then
                OUTPUT_TITLE="${BASH_REMATCH[1]}"
            fi
        fi
    done < "$CONFIG_FILE"
fi

# PDFファイル名が見つからない場合はデフォルト
if [ -z "$PDF_FILE" ]; then
    PDF_FILE="${DOC_NAME}.pdf"
    echo "Warning: Document not found in config.yaml, using default PDF filename: $PDF_FILE"
fi

# 各種パス
PDF_PATH="$PROJECT_ROOT/$RAW_PDF_DIR/$PDF_FILE"
TEXT_FILE="$PROJECT_ROOT/$INTERMEDIATE_TEXT_DIR/${DOC_NAME}.txt"
ALIGNMENT_FILE="$PROJECT_ROOT/$INTERMEDIATE_ALIGNMENT_DIR/${DOC_NAME}.json"
TRANSLATION_FILE="$PROJECT_ROOT/$TRANSLATIONS_DIR/${DOC_NAME}.json"
OUTPUT_DOCX="$PROJECT_ROOT/$OUTPUT_DIR/${DOC_NAME}.docx"

# ディレクトリの作成
mkdir -p "$PROJECT_ROOT/$INTERMEDIATE_TEXT_DIR"
mkdir -p "$PROJECT_ROOT/$INTERMEDIATE_ALIGNMENT_DIR"
mkdir -p "$PROJECT_ROOT/$TRANSLATIONS_DIR"
mkdir -p "$PROJECT_ROOT/$OUTPUT_DIR"

# ========================================
# Step 1-2: PDF抽出とアライメントJSON生成
# ========================================
extract_step() {
    echo "========================================"
    echo "Step 1: PDF → Text"
    echo "========================================"

    if [ ! -f "$PDF_PATH" ]; then
        echo "Error: PDF file not found: $PDF_PATH"
        exit 1
    fi

    echo "Converting PDF to text..."
    pdftotext "$PDF_PATH" "$TEXT_FILE"
    echo "✓ Text file created: $TEXT_FILE"

    echo ""
    echo "========================================"
    echo "Step 2: Text → Alignment JSON"
    echo "========================================"

    echo "Creating alignment JSON..."
    python3 "$SCRIPT_DIR/pdf_to_alignment.py" \
        "$TEXT_FILE" \
        -o "$ALIGNMENT_FILE" \
        -t "$TRANSLATION_FILE"

    echo "✓ Alignment JSON created: $ALIGNMENT_FILE"
    echo "✓ Translation placeholder created: $TRANSLATION_FILE"
    echo ""
    echo "📝 次のステップ（手動）:"
    echo "   1. $TRANSLATION_FILE を開く"
    echo "   2. LLM に system_prompt.md と glossary/ の内容と共に渡す"
    echo "   3. 'ja' フィールドに翻訳を記入してもらう"
    echo "   4. 翻訳済みJSONを $TRANSLATION_FILE に保存"
    echo ""
}

# ========================================
# Step 4: DOCX生成
# ========================================
generate_step() {
    echo "========================================"
    echo "Step 4: Translated JSON → DOCX"
    echo "========================================"

    if [ ! -f "$TRANSLATION_FILE" ]; then
        echo "Error: Translation file not found: $TRANSLATION_FILE"
        echo "Please complete Step 3 (manual translation) first."
        exit 1
    fi

    # 翻訳が空かチェック（簡易的に最初のjaフィールドを確認）
    first_ja=$(grep -m 1 '"ja":' "$TRANSLATION_FILE" | sed 's/.*"ja": *"\(.*\)".*/\1/')
    if [ -z "$first_ja" ]; then
        echo "Warning: Translation file appears to be empty (ja fields are blank)"
        echo "Please complete the manual translation step first."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    echo "Generating DOCX..."

    # タイトルオプション
    if [ -n "$OUTPUT_TITLE" ]; then
        python3 "$SCRIPT_DIR/json_to_docx.py" \
            "$TRANSLATION_FILE" \
            "$OUTPUT_DOCX" \
            --title "$OUTPUT_TITLE"
    else
        python3 "$SCRIPT_DIR/json_to_docx.py" \
            "$TRANSLATION_FILE" \
            "$OUTPUT_DOCX"
    fi

    echo "✓ DOCX created: $OUTPUT_DOCX"
    echo ""
    echo "✅ 完了！"
}

# ========================================
# メイン処理
# ========================================
case "$STEP" in
    extract)
        extract_step
        ;;
    generate)
        generate_step
        ;;
    all)
        extract_step
        echo "⚠️  翻訳ステップ（手動）を完了してから、次のコマンドを実行してください:"
        echo "   $0 $DOC_NAME generate"
        ;;
    *)
        echo "Error: Unknown step: $STEP"
        echo "Available steps: extract, generate, all"
        exit 1
        ;;
esac
