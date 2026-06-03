param(
    [string]$CorpusRoot = "C:\Users\Administrator\Downloads\3DGS-SLAM-Papers",
    [string]$Token = "change-this-token",
    [int]$Port = 8765
)

$env:SLAM_AI_CORPUS_ROOT = $CorpusRoot
$env:SLAM_AI_GATEWAY_TOKEN = $Token
python -m slam_ai_gateway.http_server --host 0.0.0.0 --port $Port

