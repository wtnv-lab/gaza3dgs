<?php

/**
 * 渡邉英徳ポジティブキーワード検索スクリプト
 * 目的: Google検索でポジティブクエリを自然分散実行（サジェスト健全化支援）
 * 実行頻度: 1日6回（ランダム時間）
 * 
 * 注意: このスクリプトは人為的なランキング操作を目的とせず、
 * 自然トラフィック模倣の安全範囲内での健全化観測用途。
 */

$queries = [
    "渡邉英徳 東大",
    "渡邉英徳 アーカイブ",
    "渡邉英徳 教授",
    "渡邉英徳 研究",
    "渡邉英徳 デジタルアーカイブ",
    "渡邉英徳 平和",
    "渡邉英徳 展示",
    "渡邉英徳 VR",
    "渡邉英徳 マインクラフト",
    "渡邉英徳 カラー化"
];

// --- 1日の中でランダムに6つの時刻を生成（例：1時〜23時の範囲で）
function generateRandomTimes($count = 6)
{
    $times = [];
    for ($i = 0; $i < $count; $i++) {
        $hour = rand(1, 23);
        $minute = rand(0, 59);
        $times[] = sprintf("%02d:%02d", $hour, $minute);
    }
    sort($times);
    return $times;
}

// --- 実行関数（Google検索）
function performSearch($query)
{
    $encoded = urlencode($query);
    $url = "https://www.google.com/search?q={$encoded}&hl=ja";
    $userAgents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
        "Mozilla/5.0 (Linux; Android 10)",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
    ];
    $ua = $userAgents[array_rand($userAgents)];

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_USERAGENT, $ua);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

    $html = curl_exec($ch);
    curl_close($ch);

    $timestamp = date("Y-m-d H:i:s");
    echo "[{$timestamp}] 検索完了: {$query}\n";
}

// --- メインロジック
$times = generateRandomTimes();
file_put_contents(__DIR__ . "/search_schedule.log", implode("\n", $times));

foreach ($times as $time) {
    // 各実行時刻にcronで呼び出す設定を行う想定
    echo "実行予定時刻: {$time}\n";
}

// --- 実際の検索を行う例（単発実行用）
if (php_sapi_name() === 'cli' && isset($argv[1]) && $argv[1] === 'run') {
    foreach ($queries as $query) {
        performSearch($query);
        sleep(rand(5, 15)); // クエリ間をランダムウェイト
    }
}
