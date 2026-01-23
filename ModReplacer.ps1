<#
    .SYNOPSIS
    MODフォルダ更新・文字列一括置換スクリプト

    .DESCRIPTION
    1. MOD_BASEフォルダの中身を既存のMODフォルダにコピー（上書き）
    2. config.txtに基づいて、MODフォルダ内のファイル名、フォルダ名、ファイル内の文字列を置換
    3. 文字コード(SJIS/UTF-8/UTF-8BOM)を自動判別して維持
    4. .ddsファイルの中身は置換対象外
    5. 深い階層から順に処理を行い、パスの整合性を維持

    .NOTES
    config.txtの形式: 旧文字列=新文字列 (UTF-8 BOM無し推奨)
#>

# エラー発生時にストップせず継続する設定
$ErrorActionPreference = "Continue"

# スクリプトの現在のディレクトリを取得
$ScriptDir = $PSScriptRoot

# パス設定
$SourceDir = Join-Path $ScriptDir "MOD_BASE"
$DestDir   = Join-Path $ScriptDir "MOD"
$ConfigFile = Join-Path $ScriptDir "config.txt"
$LogFile    = Join-Path $ScriptDir "log.txt"

# ログ出力用関数
function Write-Log {
    param([string]$Message, [string]$Type="INFO")
    $Timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
    $LogMsg = "[$Timestamp][$Type] $Message"
    Write-Host $LogMsg
    Add-Content -Path $LogFile -Value $LogMsg -Encoding UTF8
}

# 文字コード判定・取得用関数
function Get-FileEncoding {
    param([string]$FilePath)

    try {
        $Bytes = [System.IO.File]::ReadAllBytes($FilePath)
        
        # 1. UTF-8 BOM ありの判定 (EF BB BF)
        if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
            return [System.Text.UTF8Encoding]::new($true) # BOMあり
        }

        # 2. UTF-8 (BOMなし) か SJIS かの判定
        $Utf8NoBom = [System.Text.UTF8Encoding]::new($false, $true) # エラー時に例外を投げる設定
        try {
            $null = $Utf8NoBom.GetString($Bytes)
            return [System.Text.UTF8Encoding]::new($false) # BOMなしUTF-8
        }
        catch {
            # UTF-8として不正なバイト列がある場合はSJIS(CP932)とみなす
            return [System.Text.Encoding]::GetEncoding(932)
        }
    }
    catch {
        Write-Log "文字コード判定エラー: $FilePath" "ERROR"
        return [System.Text.Encoding]::Default
    }
}

# --- メイン処理開始 ---

Write-Log "処理を開始します..."

# 1. config.txt の読み込み
if (-not (Test-Path $ConfigFile)) {
    Write-Log "config.txt が見つかりません。処理を中止します。" "ERROR"
    exit
}

$ReplaceRules = @{}
try {
    $ConfigLines = Get-Content $ConfigFile -Encoding UTF8
    foreach ($line in $ConfigLines) {
        # コメント行(#)や空行をスキップ
        if ($line -match "^\s*#" -or [string]::IsNullOrWhiteSpace($line)) { continue }
        
        # = で分割
        if ($line -match "=") {
            $parts = $line -split "=", 2
            $OldStr = $parts[0].Trim()
            $NewStr = $parts[1].Trim()
            if ($OldStr -ne "") {
                $ReplaceRules[$OldStr] = $NewStr
            }
        }
    }
    Write-Log "置換ルールを $($ReplaceRules.Count) 件 読み込みました。"
}
catch {
    Write-Log "config.txt の読み込み中にエラーが発生しました: $_" "ERROR"
    exit
}

# 2. MOD_BASE の中身を MOD フォルダへコピー
if (-not (Test-Path $SourceDir)) {
    Write-Log "コピー元フォルダ(MOD_BASE)が見つかりません。" "ERROR"
    exit
}
if (-not (Test-Path $DestDir)) {
    Write-Log "コピー先フォルダ(MOD)が見つかりません。" "ERROR"
    exit
}

try {
    Write-Log "MOD_BASE の中身を MOD フォルダへコピー(上書き)しています..."
    
    # MOD_BASE配下の全ファイル・フォルダを取得して、MODフォルダへコピー
    # Forceを指定することで、同名ファイルがある場合は上書きします
    Copy-Item -Path "$SourceDir\*" -Destination $DestDir -Recurse -Force
}
catch {
    Write-Log "コピー処理中にエラーが発生しました: $_" "ERROR"
    # コピーエラーでも置換処理は続行するためexitしない
}

# 3. 置換処理 (MODフォルダ全体を対象)

# パスが深い順(パス文字列が長い順)にソートして取得
$Items = Get-ChildItem -Path $DestDir -Recurse | Sort-Object { $_.FullName.Length } -Descending

foreach ($Item in $Items) {
    try {
        # --- A. ファイルの中身の置換 (ファイルの場合のみ) ---
        if (-not $Item.PSIsContainer) {
            # 拡張子が .dds 以外の場合のみ中身をチェック
            if ($Item.Extension -ne ".dds") {
                
                # 文字コードを自動判別
                $CurrentEncoding = Get-FileEncoding -FilePath $Item.FullName
                
                # テキスト読み込み
                $Content = [System.IO.File]::ReadAllText($Item.FullName, $CurrentEncoding)
                $OriginalContent = $Content
                
                # ルールに従って置換
                foreach ($OldKey in $ReplaceRules.Keys) {
                    $Pattern = [regex]::Escape($OldKey)
                    $Content = $Content -replace $Pattern, $ReplaceRules[$OldKey]
                }

                # 内容に変更があれば書き込み
                if ($Content -ne $OriginalContent) {
                    [System.IO.File]::WriteAllText($Item.FullName, $Content, $CurrentEncoding)
                    Write-Log "内容置換: $($Item.FullName) ($($CurrentEncoding.EncodingName))"
                }
            }
        }

        # --- B. ファイル名・フォルダ名の置換 ---
        
        $CurrentName = $Item.Name
        $NewName = $CurrentName

        foreach ($OldKey in $ReplaceRules.Keys) {
            # ファイル名に含まれる旧文字列を置換
            $Pattern = [regex]::Escape($OldKey)
            $NewName = $NewName -replace $Pattern, $ReplaceRules[$OldKey]
        }

        if ($CurrentName -ne $NewName) {
            # リネーム処理
            Rename-Item -Path $Item.FullName -NewName $NewName -Force
            Write-Log "リネーム: $CurrentName -> $NewName"
        }

    }
    catch {
        Write-Log "エラー発生 ($($Item.FullName)): $_" "ERROR"
    }
}

Write-Log "すべての処理が完了しました。"
Read-Host "終了するにはEnterキーを押してください..."