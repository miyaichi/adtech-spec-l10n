#!/usr/bin/env python3
"""
PDF to Alignment JSON Converter

PDFから抽出したテキストをクリーンアップし、翻訳用のアライメントJSONを生成します。
また、翻訳用のプレースホルダーファイルも自動生成します。
"""
import json
import re
import sys
import argparse
from pathlib import Path


def clean_and_structure(text):
    """
    テキストをクリーンアップし、段落単位で構造化します。

    Args:
        text: 入力テキスト

    Returns:
        list: 構造化されたデータ（セクション、英語、日本語のフィールドを持つ辞書のリスト）
    """
    # 1. 共通のノイズ除去 (ページ番号、特定のヘッダー/フッター)
    text = re.sub(r'Page \d+ of \d+', '', text)
    text = re.sub(r'iab\.TECH LAB', '', text, flags=re.IGNORECASE)
    text = re.sub(r'©\d{4} IAB Technology Laboratory', '', text)
    text = re.sub(r'ads\.txt v\d+\.\d+', '', text)

    # 2. 行ごとの処理と段落の再構築
    lines = text.split('\n')
    structured_data = []

    current_section = "General"
    buffer = []

    # 見出し判定用の正規表現 (例: "1. ABSTRACT", "3.1 ACCESS METHOD")
    header_pattern = re.compile(r'^\d+(\.\d+)*\s+[A-Z\s]+$')

    for line in lines:
        line = line.strip()
        if not line:
            # 空行が来たら、バッファを書き出して段落終了とする
            if buffer:
                combined_text = ' '.join(buffer)
                # 結合時のハイフネーション処理 (例: com- \n pany -> company)
                combined_text = re.sub(r'-\s+', '', combined_text)

                structured_data.append({
                    "section": current_section,
                    "en": combined_text,
                    "ja": ""
                })
                buffer = []
            continue

        # 見出しの判定
        if header_pattern.match(line):
            # 直前のバッファがあれば書き出す
            if buffer:
                combined_text = ' '.join(buffer)
                combined_text = re.sub(r'-\s+', '', combined_text)
                structured_data.append({
                    "section": current_section,
                    "en": combined_text,
                    "ja": ""
                })
                buffer = []
            # 新しいセクション名として登録
            current_section = line
        else:
            # 本文としてバッファに追加
            buffer.append(line)

    # 残りのバッファを処理
    if buffer:
        combined_text = ' '.join(buffer)
        combined_text = re.sub(r'-\s+', '', combined_text)
        structured_data.append({
            "section": current_section,
            "en": combined_text,
            "ja": ""
        })

    return structured_data


def create_placeholder_translation(alignment_data, output_path):
    """
    翻訳用のプレースホルダーファイルを作成します。

    Args:
        alignment_data: アライメントデータ
        output_path: 出力先パス
    """
    # 空のjaフィールドを持つJSONを作成
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(alignment_data, f, indent=2, ensure_ascii=False)

    print(f"Created placeholder translation file: {output_path}")
    print("→ このファイルを LLM に渡して 'ja' フィールドを翻訳してください")


def main():
    parser = argparse.ArgumentParser(
        description='PDFから抽出したテキストをアライメントJSONに変換します',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
使用例:
  # 基本的な使用方法
  python3 pdf_to_alignment.py input.txt -o alignment.json

  # プレースホルダー翻訳ファイルも作成
  python3 pdf_to_alignment.py input.txt -o alignment.json -t translation.json

  # 標準出力に出力
  python3 pdf_to_alignment.py input.txt
        '''
    )

    parser.add_argument('input', help='入力テキストファイル（pdftotextの出力）')
    parser.add_argument('-o', '--output', help='出力先のアライメントJSONファイル')
    parser.add_argument('-t', '--translation-placeholder',
                       help='翻訳用プレースホルダーファイルのパス（0バイトではなく、空のjaフィールドを持つJSON）')

    args = parser.parse_args()

    try:
        # 入力ファイルの読み込み
        input_path = Path(args.input)
        if not input_path.exists():
            print(f"Error: Input file not found: {args.input}", file=sys.stderr)
            sys.exit(1)

        with open(input_path, 'r', encoding='utf-8') as f:
            raw_text = f.read()

        # データの構造化
        data = clean_and_structure(raw_text)

        # JSON出力
        json_output = json.dumps(data, indent=2, ensure_ascii=False)

        if args.output:
            # ファイルに出力
            output_path = Path(args.output)
            output_path.parent.mkdir(parents=True, exist_ok=True)

            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(json_output)

            print(f"Alignment JSON created: {args.output}")
        else:
            # 標準出力に出力
            print(json_output)

        # プレースホルダー翻訳ファイルの作成
        if args.translation_placeholder:
            placeholder_path = Path(args.translation_placeholder)
            placeholder_path.parent.mkdir(parents=True, exist_ok=True)
            create_placeholder_translation(data, placeholder_path)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
