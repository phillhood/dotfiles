function shellbench {
  1..5 | ForEach-Object {
    $ms = (Measure-Command { pwsh -NoLogo -Command exit }).TotalMilliseconds
    '{0,6:N0} ms' -f $ms
  }
}

function emocode([Parameter(Mandatory)][string]$Text) {
  $sb = [Text.StringBuilder]::new()
  foreach ($ch in $Text.ToCharArray()) {
    $n = [int]$ch
    switch ($n) {
      34 { [void]$sb.Append('\"'); continue }
      92 { [void]$sb.Append('\\'); continue }
      10 { [void]$sb.Append('\n'); continue }
      13 { [void]$sb.Append('\r'); continue }
      9 { [void]$sb.Append('\t'); continue }
      8 { [void]$sb.Append('\b'); continue }
      12 { [void]$sb.Append('\f'); continue }
      default {
        if ($n -lt 0x20 -or $n -ge 0x7f) { [void]$sb.AppendFormat('\u{0:x4}', $n) }
        else { [void]$sb.Append($ch) }
      }
    }
  }
  $out = $sb.ToString()
  $out
  Set-Clipboard -Value $out
}
