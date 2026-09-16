#Requires -Version 5.1
$Port = 18080
$Json = '{"Valid":true,"Expiration":"2099-12-31T23:59:59"}'
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$listener.Server.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
$listener.Start()
$ascii = [Text.Encoding]::ASCII
$utf8 = [Text.Encoding]::UTF8
$body = $utf8.GetBytes($Json)
try {
    while ($true) {
        try { $client = $listener.AcceptTcpClient() } catch { break }
        try {
            $client.ReceiveTimeout = 5000
            $stream = $client.GetStream()
            $buf = New-Object byte[] 8192
            [void]$stream.Read($buf, 0, $buf.Length)
            $nl = [char]13 + [char]10
            $header = "HTTP/1.1 200 OK" + $nl +
                "Content-Type: application/json; charset=utf-8" + $nl +
                "Content-Length: $($body.Length)" + $nl +
                "Connection: close" + $nl +
                "Cache-Control: no-store" + $nl + $nl
            $hb = $ascii.GetBytes($header)
            $stream.Write($hb, 0, $hb.Length)
            $stream.Write($body, 0, $body.Length)
            $stream.Flush()
        } catch {
        } finally {
            try { $client.Close() } catch {}
        }
    }
} finally {
    try { $listener.Stop() } catch {}
}
