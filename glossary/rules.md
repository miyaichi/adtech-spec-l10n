# Ad Tech Standard Translation Rules & Glossary (v2025-12)

## 1. Basic Translation Rules (基本ルール)

1.  **Header Format (見出しの形式):**
    * Use "English Original (Japanese Translation)" format for section titles.
    * Example: "Scope (スコープ)", "About ads.txt (ads.txtについて)"

2.  **Untranslated Elements (翻訳しない要素):**
    * **Variables & Fields:** Do NOT translate variable names, field keys, or enumerated values. Keep them in exact English casing.
        * *Examples:* `CONTACT`, `SUBDOMAIN`, `OWNERDOMAIN`, `seller_id`, `is_confidential`, `DIRECT`, `RESELLER`, `PUBLISHER`, `INTERMEDIARY`, `BOTH`.
    * **Domain Names:** `Root Domain`, `Public Suffix` (Katakana "パブリックサフィックス" is acceptable in explanations, but English is preferred for definitions).

3.  **Term Selection (訳語の選択):**
    * **Inventory:**
        * System context: "インベントリ" (e.g., "Ad inventory hosted by...")
        * Business context: "在庫" or "インベントリ" (e.g., "Counterfeit inventory" -> "偽造在庫")
    * **Authorized:**
        * Certification/Status: "公認" or "認定" (e.g., "Authorized System" -> "公認システム")
        * Permission: "許可" or "権限" (e.g., "Authorized to sell" -> "販売を許可された")
    * **File Format:** "ファイルフォーマット" (Priority) or "ファイル形式".

4.  **Tone & Style (文体):**
    * Use "である" style (Technical/Formal).
    * Prioritize accuracy for definitions/specifications.
    * Prioritize readability for Introductions/Abstracts.
