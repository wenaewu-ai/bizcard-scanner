# 名片掃描器 v1.1.0

Flutter Android APP — Ollama 雲端 AI 辨識 + QR 名片分享

---

## 如何取得 APK（5 分鐘）

### 步驟 1：建立 GitHub Repo

1. 到 [github.com/new](https://github.com/new) 建立新 repo（名稱隨意，建議 `biz-card-scanner`）
2. 設定為 **Public** 或 **Private** 皆可

### 步驟 2：上傳程式碼

```bash
git init
git add .
git commit -m "init"
git remote add origin https://github.com/你的帳號/biz-card-scanner.git
git push -u origin main
```

### 步驟 3：等待 Build

- Push 後 GitHub Actions 自動開始 build（約 3–5 分鐘）
- 到 repo 頁面 → `Actions` 分頁 → 點最新的 workflow run
- 等綠色勾勾出現

### 步驟 4：下載 APK

- Workflow run 頁面最下方 **Artifacts** 區塊
- 點 `biz-card-scanner-xxxxxxxx` 下載 ZIP
- 解壓後得到 `app-release.apk`

### 步驟 5：安裝到手機

1. 把 APK 傳到 Android 手機（USB / Google Drive / Line 都行）
2. 手機開啟 APK 檔案
3. 若出現「允許安裝未知來源」→ 允許
4. 安裝完成！

---

## 首次使用設定

1. 開啟 APP → 點底部「設定」
2. 填入 **Ollama API Key**（到 [ollama.com/settings/api](https://ollama.com/settings/api) 申請）
3. 模型保持 `llava:latest`，端點保持預設
4. 點「儲存設定」

---

## 功能

| 功能 | 說明 |
|------|------|
| 拍照掃描 | 直接啟動相機，對準名片拍照 |
| AI 辨識 | Ollama llava 模型自動填入欄位 |
| 辨識欄位 | 姓名、職稱、部門、公司、統編、手機、市話、傳真、Email、地址、網址、LINE、備註 |
| 編輯 | 辨識後可逐欄修正 |
| 搜尋 | 輸入前幾碼即時自動完成 |
| QR 分享 | 產生標準 vCard QR，對方掃一掃存入通訊錄 |
| 匯出 | vCard (.vcf)、Excel CSV (.csv)、JSON 備份 |
| 本機儲存 | 所有資料存在手機，不上傳任何伺服器 |

---

## 專案結構

```
lib/
├── main.dart
├── models/
│   └── contact.dart          # Contact 資料模型 + vCard 產生
├── services/
│   ├── ollama_service.dart   # Ollama API 呼叫
│   ├── contact_store.dart    # SharedPreferences CRUD
│   ├── export_service.dart   # vCard / CSV / JSON 匯出
│   └── settings_service.dart # API Key 設定儲存
├── screens/
│   ├── scan_screen.dart      # 拍照 + AI 辨識
│   ├── contacts_screen.dart  # 聯絡人列表 + 搜尋
│   ├── qr_share_screen.dart  # QR 名片產生
│   ├── edit_contact_screen.dart
│   └── settings_screen.dart
└── widgets/
    └── contact_avatar.dart   # 彩色縮寫頭像

.github/workflows/
└── build_apk.yml             # GitHub Actions 自動 build APK
```

---

## 支援的 Ollama 視覺模型

| 模型 | 說明 |
|------|------|
| `llava:latest` | 預設，均衡速度與準確度 |
| `llava:13b` | 更準確，較慢 |
| `llava-phi3` | 較小較快 |
| `bakllava` | 替代選項 |
