[CmdletBinding()]
param(
    [string]$OutputDir = (Join-Path (Get-Location) 'photoshop_cutout'),
    [string]$BaseName = ('cutout_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [string]$SourceDocumentName,
    [string]$PlacedLayerName = 'Codex Cutout Refined',
    [string]$ExistingLayerName = 'Codex Cutout Refined',
    [switch]$SkipPlaceBack,
    [switch]$SkipWhiteExports,
    [switch]$KeepPreviousCodexLayer,
    [switch]$DisableExistingCutoutFallback
)

$ErrorActionPreference = 'Stop'

function Write-Result {
    param(
        [string]$Key,
        [string]$Value
    )

    '{0}={1}' -f $Key, $Value
}

function New-TempFilePath {
    param(
        [string]$Extension
    )

    Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString() + $Extension)
}

function Set-AsciiFile {
    param(
        [string]$Path,
        [string]$Content
    )

    Set-Content -LiteralPath $Path -Value $Content -Encoding ASCII
}

function Convert-ToJsSingleQuotedString {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    $escaped = $Value.Replace('\\', '\\\\').Replace("'", "\\'")
    return $escaped
}

function Invoke-PhotoshopJsx {
    param(
        [string]$JsxSource
    )

    $jsxPath = New-TempFilePath '.jsx'
    $runnerPath = New-TempFilePath '.vbs'

    $runner = @'
On Error Resume Next
Set app = GetObject(, "Photoshop.Application")
If Err.Number <> 0 Then
  WScript.Echo "ERROR:CONNECT:Open Photoshop and the target document first."
  WScript.Quit 1
End If
result = app.DoJavaScriptFile(WScript.Arguments(0))
If Err.Number <> 0 Then
  WScript.Echo "ERROR:RUN:" & Err.Description
  WScript.Quit 1
End If
WScript.Echo result
'@

    try {
        Set-AsciiFile -Path $jsxPath -Content $JsxSource
        Set-AsciiFile -Path $runnerPath -Content $runner
        & cscript //nologo $runnerPath $jsxPath
    }
    finally {
        Remove-Item -LiteralPath $jsxPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $runnerPath -Force -ErrorAction SilentlyContinue
    }
}

function Convert-PngToWhiteBackground {
    param(
        [string]$InputPng,
        [string]$OutputJpg,
        [string]$OutputPng
    )

    Add-Type -AssemblyName System.Drawing

    $img = [System.Drawing.Image]::FromFile($InputPng)
    try {
        $bmp = [System.Drawing.Bitmap]::new(
            $img.Width,
            $img.Height,
            [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
        )
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $graphics.Clear([System.Drawing.Color]::White)
                $graphics.DrawImage($img, 0, 0, $img.Width, $img.Height)
            }
            finally {
                $graphics.Dispose()
            }

            $jpgCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
                Where-Object { $_.MimeType -eq 'image/jpeg' } |
                Select-Object -First 1

            $quality = [System.Drawing.Imaging.Encoder]::Quality
            $encoderParams = [System.Drawing.Imaging.EncoderParameters]::new(1)
            $encoderParams.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new($quality, 95L)

            $bmp.Save($OutputJpg, $jpgCodec, $encoderParams)
            $bmp.Save($OutputPng, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $bmp.Dispose()
        }
    }
    finally {
        $img.Dispose()
    }
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$transparentFull = Join-Path $OutputDir ($BaseName + '_transparent_full.png')
$transparentTrim = Join-Path $OutputDir ($BaseName + '_transparent_trim.png')
$whiteJpg = Join-Path $OutputDir ($BaseName + '_white.jpg')
$whitePng = Join-Path $OutputDir ($BaseName + '_white.png')

$jsFull = Convert-ToJsSingleQuotedString ($transparentFull -replace '\\', '/')
$jsTrim = Convert-ToJsSingleQuotedString ($transparentTrim -replace '\\', '/')
$jsSourceDocumentName = Convert-ToJsSingleQuotedString $SourceDocumentName
$jsPlacedLayerName = Convert-ToJsSingleQuotedString $PlacedLayerName
$jsExistingLayerName = Convert-ToJsSingleQuotedString $ExistingLayerName
$placeBack = if ($SkipPlaceBack) { 'false' } else { 'true' }
$removePrevious = if ($KeepPreviousCodexLayer) { 'false' } else { 'true' }
$allowFallback = if ($DisableExistingCutoutFallback) { 'false' } else { 'true' }

$jsx = @'
(function(){
  app.displayDialogs = DialogModes.NO;

  var requestedDocumentName = '__SOURCE_DOCUMENT_NAME__';
  var placedLayerName = '__PLACED_LAYER_NAME__';
  var existingLayerName = '__EXISTING_LAYER_NAME__';

  function safeClose(doc) {
    try { doc.close(SaveOptions.DONOTSAVECHANGES); } catch (e) {}
  }

  function result(parts) {
    return parts.join('\n');
  }

  function exportTransparentOutputs(doc, fullFile, trimFile) {
    var pngOpts = new PNGSaveOptions();
    doc.saveAs(fullFile, pngOpts, true, Extension.LOWERCASE);

    var trimCopy = doc.duplicate('codex_cutout_trim_tmp', false);
    app.activeDocument = trimCopy;
    try { trimCopy.trim(TrimType.TRANSPARENT, true, true, true, true); } catch (e) {}
    trimCopy.saveAs(trimFile, pngOpts, true, Extension.LOWERCASE);
    safeClose(trimCopy);
    app.activeDocument = doc;
  }

  function chooseSourceDocument() {
    if (app.documents.length === 0) {
      return null;
    }

    var src = app.activeDocument;

    if (requestedDocumentName) {
      for (var i = 0; i < app.documents.length; i++) {
        if (app.documents[i].name === requestedDocumentName) {
          src = app.documents[i];
          break;
        }
      }
    }

    for (var j = 0; j < app.documents.length; j++) {
      var candidate = app.documents[j];
      if (candidate.name === src.name && candidate.layers.length > src.layers.length) {
        src = candidate;
      }
    }

    if (src.name.indexOf('codex_') === 0) {
      for (var k = 0; k < app.documents.length; k++) {
        if (app.documents[k].name.indexOf('codex_') !== 0) {
          src = app.documents[k];
          break;
        }
      }
    }

    return src;
  }

  function getTopNamedLayer(doc, layerName) {
    if (!doc || !doc.layers || doc.layers.length === 0) {
      return null;
    }

    for (var i = 0; i < doc.layers.length; i++) {
      if (doc.layers[i].name === layerName) {
        return doc.layers[i];
      }
    }

    return null;
  }

  var src = chooseSourceDocument();
  if (!src) {
    return result([
      'status=error',
      'message=No open Photoshop document was found.'
    ]);
  }

  var previousLayer = null;
  var temp = null;
  var fullFile = new File('__FULL__');
  var trimFile = new File('__TRIM__');

  try {
    app.activeDocument = src;

    previousLayer = getTopNamedLayer(src, existingLayerName);
    if (__REMOVE_PREVIOUS__ && previousLayer) {
      try { previousLayer.visible = false; } catch (e) {}
    }

    temp = src.duplicate('codex_cutout_tmp', true);
    app.activeDocument = temp;

    try {
      if (temp.activeLayer.isBackgroundLayer) temp.activeLayer.isBackgroundLayer = false;
    } catch (e) {}

    var usedExistingLayer = false;
    try {
      var cutoutDesc = new ActionDescriptor();
      cutoutDesc.putBoolean(stringIDToTypeID('sampleAllLayers'), false);
      executeAction(stringIDToTypeID('autoCutout'), cutoutDesc, DialogModes.NO);

      try { temp.selection.smooth(2); } catch (e) {}
      try { temp.selection.contract(1); } catch (e) {}
      try { temp.selection.feather(0.6); } catch (e) {}

      temp.selection.invert();
      temp.selection.clear();
      temp.selection.deselect();
      temp.activeLayer.name = placedLayerName;
    } catch (cutoutError) {
      safeClose(temp);
      temp = null;

      if (!__ALLOW_FALLBACK__ || !previousLayer) {
        throw cutoutError;
      }

      try { previousLayer.visible = true; } catch (e) {}
      temp = src.duplicate('codex_cutout_existing_tmp', false);
      app.activeDocument = temp;

      var foundExisting = false;
      for (var m = 0; m < temp.layers.length; m++) {
        var layer = temp.layers[m];
        if (layer.name === existingLayerName && !foundExisting) {
          temp.activeLayer = layer;
          try { layer.visible = true; } catch (e) {}
          foundExisting = true;
        } else {
          try { layer.visible = false; } catch (e) {}
        }
      }

      if (!foundExisting) {
        throw cutoutError;
      }

      usedExistingLayer = true;
    }

    exportTransparentOutputs(temp, fullFile, trimFile);

    var placedBack = false;
    if (__PLACE_BACK__ && !usedExistingLayer) {
      app.activeDocument = src;
      var placeDesc = new ActionDescriptor();
      placeDesc.putPath(charIDToTypeID('null'), fullFile);
      placeDesc.putEnumerated(charIDToTypeID('FTcs'), charIDToTypeID('QCSt'), charIDToTypeID('Qcsa'));
      var offsetDesc = new ActionDescriptor();
      offsetDesc.putUnitDouble(charIDToTypeID('Hrzn'), charIDToTypeID('#Pxl'), 0.0);
      offsetDesc.putUnitDouble(charIDToTypeID('Vrtc'), charIDToTypeID('#Pxl'), 0.0);
      placeDesc.putObject(charIDToTypeID('Ofst'), charIDToTypeID('Ofst'), offsetDesc);
      executeAction(charIDToTypeID('Plc '), placeDesc, DialogModes.NO);
      try { src.activeLayer.name = placedLayerName; } catch (e) {}
      placedBack = true;

      if (__REMOVE_PREVIOUS__ && previousLayer) {
        try { previousLayer.remove(); } catch (e) {}
      }
    } else if (__PLACE_BACK__ && usedExistingLayer) {
      placedBack = true;
      try { previousLayer.visible = true; } catch (e) {}
    } else if (previousLayer) {
      try { previousLayer.visible = true; } catch (e) {}
    }

    safeClose(temp);
    temp = null;
    app.activeDocument = src;

    return result([
      'status=ok',
      'source_document=' + src.name,
      'transparent_full=' + fullFile.fsName,
      'transparent_trim=' + trimFile.fsName,
      'placed_back=' + placedBack,
      'used_existing_cutout=' + usedExistingLayer
    ]);
  } catch (e) {
    if (previousLayer) {
      try { previousLayer.visible = true; } catch (_) {}
    }
    if (temp) safeClose(temp);
    return result([
      'status=error',
      'message=' + e
    ]);
  }
})();
'@

$jsx = $jsx.Replace('__FULL__', $jsFull)
$jsx = $jsx.Replace('__TRIM__', $jsTrim)
$jsx = $jsx.Replace('__SOURCE_DOCUMENT_NAME__', $jsSourceDocumentName)
$jsx = $jsx.Replace('__PLACED_LAYER_NAME__', $jsPlacedLayerName)
$jsx = $jsx.Replace('__EXISTING_LAYER_NAME__', $jsExistingLayerName)
$jsx = $jsx.Replace('__PLACE_BACK__', $placeBack)
$jsx = $jsx.Replace('__REMOVE_PREVIOUS__', $removePrevious)
$jsx = $jsx.Replace('__ALLOW_FALLBACK__', $allowFallback)

$rawResult = Invoke-PhotoshopJsx -JsxSource $jsx
$lines = @($rawResult | Where-Object { $_ -and $_.Trim() -ne '' })

if (-not $lines) {
    throw 'Photoshop script returned no output.'
}

$result = @{}
foreach ($line in $lines) {
    $text = [string]$line
    $idx = $text.IndexOf('=')
    if ($idx -gt 0) {
        $result[$text.Substring(0, $idx)] = $text.Substring($idx + 1)
    }
}

if ((-not $result.ContainsKey('status')) -or $result['status'] -ne 'ok') {
    $message = $result['message']
    if (-not $message) {
        $message = ($lines -join [Environment]::NewLine)
    }
    throw $message
}

if (-not $SkipWhiteExports) {
    Convert-PngToWhiteBackground -InputPng $transparentFull -OutputJpg $whiteJpg -OutputPng $whitePng
    $result['white_jpg'] = $whiteJpg
    $result['white_png'] = $whitePng
}

$result['output_dir'] = (Resolve-Path -LiteralPath $OutputDir).Path
$result['base_name'] = $BaseName

foreach ($key in @(
    'status',
    'source_document',
    'placed_back',
    'used_existing_cutout',
    'transparent_full',
    'transparent_trim',
    'white_jpg',
    'white_png',
    'output_dir',
    'base_name'
)) {
    if ($result.ContainsKey($key)) {
        Write-Output (Write-Result -Key $key -Value $result[$key])
    }
}
