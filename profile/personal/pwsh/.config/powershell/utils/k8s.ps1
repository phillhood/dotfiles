function kdeploy([string]$Mode) {
  $name = Split-Path -Leaf $PWD
  $output = helm template $name . -f "$HOME/homelab/k8s/values.yaml" | Out-String
  $output | kubectl apply -f -

  if ($Mode -eq 'r') {
    $m = [regex]::Match($output, 'namespace:\s*(\S+)')
    $ns = if ($m.Success) { $m.Groups[1].Value } else { 'default' }
    kubectl rollout restart deployment $name -n $ns 2>$null
    if ($LASTEXITCODE) { kubectl rollout restart deployment -l "app=$name" -n $ns 2>$null }
  }
}
