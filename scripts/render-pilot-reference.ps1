param([string]$PdfPath, [string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
$null = [Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime]
$null = [Windows.Storage.Streams.InMemoryRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
$asyncMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
function Await-Result($Operation, [Type]$ResultType) {
  $task = $asyncMethod.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
  $task.GetAwaiter().GetResult()
}
$pdfFile = Await-Result ([Windows.Storage.StorageFile]::GetFileFromPathAsync($PdfPath)) ([Windows.Storage.StorageFile])
$document = Await-Result ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($pdfFile)) ([Windows.Data.Pdf.PdfDocument])
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Write-Output "BA reference PDF pages: $($document.PageCount)"
foreach ($index in @(0,6,7,8,9,10,11,12,13,14)) {
  if ($index -ge $document.PageCount) { continue }
  $page = $document.GetPage($index)
  $stream = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
  $actionMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and -not $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } | Select-Object -First 1
  $renderTask = $actionMethod.Invoke($null, @($page.RenderToStreamAsync($stream)))
  $null = $renderTask.GetAwaiter().GetResult()
  $stream.Seek(0)
  $inputStream = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
  $outputPath = Join-Path $OutputDirectory ('ba_{0:D2}.png' -f ($index+1))
  $outputStream = [System.IO.File]::Create($outputPath)
  $inputStream.CopyTo($outputStream)
  $outputStream.Dispose()
  $inputStream.Dispose()
  $stream.Dispose()
  $page.Dispose()
  Write-Output $outputPath
}
