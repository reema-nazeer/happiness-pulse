# Homey Happiness Pulse — Windows installer for Revenue / Editorial.
#
# Run once in PowerShell (right-click PowerShell → Run as administrator
# is NOT needed):
#
#   powershell -ExecutionPolicy Bypass -Command "iwr 'https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main/Scripts/install-revenue-editorial-windows.ps1' -UseBasicParsing | iex"
#
# What this does:
#   1. Writes the pulse app script to %USERPROFILE%\homey-pulse\pulse.ps1
#   2. Creates a Windows Scheduled Task that runs it Mon-Fri at 09:00,
#      11:00, 14:00 and 16:00 — matching the macOS schedule.
#   3. Sends an install event to the shared Google Sheet.
#   4. Launches the pulse immediately so you can test it.

$ErrorActionPreference = "Stop"

$DEPARTMENT   = "Revenue"
$SUBDEPT      = "Editorial"
$WEBHOOK_URL  = "https://script.google.com/macros/s/AKfycbwZbrkn78c7IjYgbjfr56Xhymxh-kADnHFmxHff6seyOVMc5xVaowub4mlCEX_rVA4J/exec"
$BASE_DIR     = "$env:USERPROFILE\homey-pulse"
$PULSE_SCRIPT = "$BASE_DIR\pulse.ps1"
$FLAGS_DIR    = "$BASE_DIR\flags"
$TASK_NAME    = "HomeyHappinessPulse"

Write-Host ""
Write-Host "  ⚡ Homey Happiness Pulse — installing for $DEPARTMENT / $SUBDEPT"
Write-Host "  =================================================="
Write-Host ""

# Step 1 — create folders
New-Item -ItemType Directory -Force -Path $BASE_DIR  | Out-Null
New-Item -ItemType Directory -Force -Path $FLAGS_DIR | Out-Null

# Step 2 — write the pulse UI script
Write-Host "  [1/3] Writing pulse app..."
$pulseScript = @'
# Homey Happiness Pulse — daily popup for Revenue / Editorial (Windows)
param([switch]$Test)

$DEPARTMENT  = "Revenue"
$SUBDEPT     = "Editorial"
$WEBHOOK_URL = "https://script.google.com/macros/s/AKfycbwZbrkn78c7IjYgbjfr56Xhymxh-kADnHFmxHff6seyOVMc5xVaowub4mlCEX_rVA4J/exec"
$BASE_DIR    = "$env:USERPROFILE\homey-pulse"
$FLAGS_DIR   = "$BASE_DIR\flags"
$TODAY       = (Get-Date -Format "yyyy-MM-dd")
$FLAG_FILE   = "$FLAGS_DIR\$TODAY"

# Skip if already submitted today (unless --Test)
if (-not $Test -and (Test-Path $FLAG_FILE)) { exit 0 }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ── Colours ──────────────────────────────────────────────────────────────────
$purple     = [System.Drawing.Color]::FromArgb(99,  51, 230)
$bgCard     = [System.Drawing.Color]::FromArgb(245, 245, 252)
$bgWindow   = [System.Drawing.Color]::FromArgb(20,  20,  30)
$textDark   = [System.Drawing.Color]::FromArgb(15,  15,  20)
$textGrey   = [System.Drawing.Color]::FromArgb(120, 120, 140)
$btnYellow  = [System.Drawing.Color]::FromArgb(210, 240, 40)
$btnHover   = [System.Drawing.Color]::FromArgb(190, 220, 20)
$white      = [System.Drawing.Color]::White

# ── Emoji + label map ─────────────────────────────────────────────────────────
function Get-ScoreLabel($s) {
    switch ($s) {
        1  { return @("😞", "Very Unhappy",  [System.Drawing.Color]::FromArgb(220,60,60))   }
        2  { return @("😟", "Unhappy",       [System.Drawing.Color]::FromArgb(220,80,50))   }
        3  { return @("😕", "A Bit Down",    [System.Drawing.Color]::FromArgb(220,110,40))  }
        4  { return @("😐", "Below Average", [System.Drawing.Color]::FromArgb(210,150,30))  }
        5  { return @("😶", "Neutral",       [System.Drawing.Color]::FromArgb(200,170,30))  }
        6  { return @("🙂", "Okay",          [System.Drawing.Color]::FromArgb(170,190,30))  }
        7  { return @("😊", "Good",          [System.Drawing.Color]::FromArgb(120,190,40))  }
        8  { return @("😄", "Happy",         [System.Drawing.Color]::FromArgb(80, 190,60))  }
        9  { return @("😁", "Very Happy",    [System.Drawing.Color]::FromArgb(50, 180,80))  }
        10 { return @("🤩", "Excellent!",    [System.Drawing.Color]::FromArgb(30, 170,100)) }
        default { return @("😶", "Slide to rate", $textGrey) }
    }
}

# ── Form ──────────────────────────────────────────────────────────────────────
$form                  = New-Object System.Windows.Forms.Form
$form.Text             = "Homey Happiness Pulse"
$form.Size             = New-Object System.Drawing.Size(480, 540)
$form.StartPosition    = "CenterScreen"
$form.BackColor        = $bgWindow
$form.FormBorderStyle  = "FixedSingle"
$form.MaximizeBox      = $false
$form.MinimizeBox      = $false
$form.TopMost          = $true
$form.Font             = New-Object System.Drawing.Font("Segoe UI", 10)

# Card panel
$card                  = New-Object System.Windows.Forms.Panel
$card.Size             = New-Object System.Drawing.Size(420, 460)
$card.Location         = New-Object System.Drawing.Point(28, 28)
$card.BackColor        = $bgCard
$form.Controls.Add($card)

# Round corners on card (paint event)
$card.Add_Paint({
    param($s, $e)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = $s.ClientRectangle
    $radius = 20
    $path.AddArc($r.X, $r.Y, $radius*2, $radius*2, 180, 90)
    $path.AddArc($r.Right - $radius*2, $r.Y, $radius*2, $radius*2, 270, 90)
    $path.AddArc($r.Right - $radius*2, $r.Bottom - $radius*2, $radius*2, $radius*2, 0, 90)
    $path.AddArc($r.X, $r.Bottom - $radius*2, $radius*2, $radius*2, 90, 90)
    $path.CloseAllFigures()
    $s.Region = New-Object System.Drawing.Region($path)
})

# Logo label (text stand-in)
$logo              = New-Object System.Windows.Forms.Label
$logo.Text         = "homey⚡"
$logo.Font         = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$logo.ForeColor    = $purple
$logo.AutoSize     = $true
$logo.Location     = New-Object System.Drawing.Point(0, 22)
$logo.Anchor       = "Top"
$card.Controls.Add($logo)
# Centre logo after add
$logo.Location = New-Object System.Drawing.Point(($card.Width - $logo.Width) / 2, 22)

# Question label
$question              = New-Object System.Windows.Forms.Label
$question.Text         = "How happy are you at Homey today?"
$question.Font         = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$question.ForeColor    = $textDark
$question.Size         = New-Object System.Drawing.Size(380, 40)
$question.Location     = New-Object System.Drawing.Point(20, 65)
$question.TextAlign    = "MiddleCenter"
$card.Controls.Add($question)

# Emoji label
$emojiLabel            = New-Object System.Windows.Forms.Label
$emojiLabel.Text       = "😶"
$emojiLabel.Font       = New-Object System.Drawing.Font("Segoe UI Emoji", 28)
$emojiLabel.AutoSize   = $true
$emojiLabel.Location   = New-Object System.Drawing.Point(190, 112)
$card.Controls.Add($emojiLabel)

# Score label
$scoreLabel            = New-Object System.Windows.Forms.Label
$scoreLabel.Text       = "Slide to rate"
$scoreLabel.Font       = New-Object System.Drawing.Font("Segoe UI", 10)
$scoreLabel.ForeColor  = $textGrey
$scoreLabel.AutoSize   = $true
$scoreLabel.Location   = New-Object System.Drawing.Point(165, 158)
$card.Controls.Add($scoreLabel)

# Slider (TrackBar)
$slider                = New-Object System.Windows.Forms.TrackBar
$slider.Minimum        = 1
$slider.Maximum        = 10
$slider.Value          = 5
$slider.TickFrequency  = 1
$slider.LargeChange    = 1
$slider.Size           = New-Object System.Drawing.Size(370, 45)
$slider.Location       = New-Object System.Drawing.Point(22, 185)
$slider.BackColor      = $bgCard
$card.Controls.Add($slider)

# Min/Max labels
$minLbl            = New-Object System.Windows.Forms.Label
$minLbl.Text       = "1"
$minLbl.ForeColor  = $textGrey
$minLbl.Font       = New-Object System.Drawing.Font("Segoe UI", 9)
$minLbl.AutoSize   = $true
$minLbl.Location   = New-Object System.Drawing.Point(22, 232)
$card.Controls.Add($minLbl)

$maxLbl            = New-Object System.Windows.Forms.Label
$maxLbl.Text       = "10"
$maxLbl.ForeColor  = $textGrey
$maxLbl.Font       = New-Object System.Drawing.Font("Segoe UI", 9)
$maxLbl.AutoSize   = $true
$maxLbl.Location   = New-Object System.Drawing.Point(368, 232)
$card.Controls.Add($maxLbl)

# Feedback box
$feedbackBox               = New-Object System.Windows.Forms.TextBox
$feedbackBox.Multiline     = $true
$feedbackBox.Size          = New-Object System.Drawing.Size(376, 70)
$feedbackBox.Location      = New-Object System.Drawing.Point(22, 255)
$feedbackBox.BackColor     = $white
$feedbackBox.ForeColor     = $textGrey
$feedbackBox.Font          = New-Object System.Drawing.Font("Segoe UI", 10)
$feedbackBox.Text          = "Anything you'd like to share? (optional)"
$feedbackBox.BorderStyle   = "FixedSingle"
$card.Controls.Add($feedbackBox)

$feedbackBox.Add_Enter({
    if ($feedbackBox.Text -eq "Anything you'd like to share? (optional)") {
        $feedbackBox.Text      = ""
        $feedbackBox.ForeColor = $textDark
    }
})
$feedbackBox.Add_Leave({
    if ($feedbackBox.Text -eq "") {
        $feedbackBox.Text      = "Anything you'd like to share? (optional)"
        $feedbackBox.ForeColor = $textGrey
    }
})

# Submit button
$submitBtn             = New-Object System.Windows.Forms.Button
$submitBtn.Text        = "Submit"
$submitBtn.Size        = New-Object System.Drawing.Size(376, 48)
$submitBtn.Location    = New-Object System.Drawing.Point(22, 338)
$submitBtn.FlatStyle   = "Flat"
$submitBtn.BackColor   = $btnYellow
$submitBtn.ForeColor   = $textDark
$submitBtn.Font        = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$submitBtn.FlatAppearance.BorderSize = 0
$submitBtn.Cursor      = [System.Windows.Forms.Cursors]::Hand
$card.Controls.Add($submitBtn)

$submitBtn.Add_MouseEnter({ $submitBtn.BackColor = $btnHover })
$submitBtn.Add_MouseLeave({ $submitBtn.BackColor = $btnYellow })

# Anonymous note
$anonLabel             = New-Object System.Windows.Forms.Label
$anonLabel.Text        = "100% Anonymous — your name is never recorded"
$anonLabel.Font        = New-Object System.Drawing.Font("Segoe UI", 9)
$anonLabel.ForeColor   = $purple
$anonLabel.AutoSize    = $true
$anonLabel.Location    = New-Object System.Drawing.Point(90, 398)
$card.Controls.Add($anonLabel)

# ── Slider change handler ─────────────────────────────────────────────────────
$slider.Add_ValueChanged({
    $info = Get-ScoreLabel $slider.Value
    $emojiLabel.Text      = $info[0]
    $scoreLabel.Text      = $info[1]
    $scoreLabel.ForeColor = $info[2]
    $emojiLabel.Location  = New-Object System.Drawing.Point(($card.Width - $emojiLabel.Width) / 2, 112)
    $scoreLabel.Location  = New-Object System.Drawing.Point(($card.Width - $scoreLabel.Width) / 2, 158)
})

# ── Submit handler ────────────────────────────────────────────────────────────
$submitBtn.Add_Click({
    $score    = $slider.Value
    $feedback = $feedbackBox.Text
    if ($feedback -eq "Anything you'd like to share? (optional)") { $feedback = "" }

    $body = @{
        type           = "happiness"
        score          = $score
        feedback       = $feedback
        department     = $DEPARTMENT
        sub_department = $SUBDEPT
        timestamp      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        version        = "1.0.0-win"
        source         = "windows-powershell"
        os_version     = [System.Environment]::OSVersion.VersionString
    } | ConvertTo-Json

    try {
        $null = Invoke-WebRequest -Uri $WEBHOOK_URL -Method Post `
            -ContentType "application/json" -Body $body -UseBasicParsing
        # Write today's flag so it won't show again today
        New-Item -ItemType File -Force -Path $FLAG_FILE | Out-Null
    } catch {
        # Submit silently — flag still written so user isn't pestered again
        New-Item -ItemType File -Force -Path $FLAG_FILE | Out-Null
    }
    $form.Close()
})

# Centre emoji/score on load
$form.Add_Shown({
    $emojiLabel.Location = New-Object System.Drawing.Point(($card.Width - $emojiLabel.Width) / 2, 112)
    $scoreLabel.Location = New-Object System.Drawing.Point(($card.Width - $scoreLabel.Width) / 2, 158)
    $form.Activate()
})

[void]$form.ShowDialog()
'@

Set-Content -Path $PULSE_SCRIPT -Value $pulseScript -Encoding UTF8
Write-Host "         Written to $PULSE_SCRIPT"

# Step 3 — create scheduled task (Mon–Fri at 09:00, 11:00, 14:00, 16:00)
Write-Host "  [2/3] Registering scheduled task..."

$action  = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PULSE_SCRIPT`""

$triggers = @(
    $(New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "09:00"),
    $(New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "11:00"),
    $(New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "14:00"),
    $(New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At "16:00")
)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

# Remove existing task silently before re-registering
Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName $TASK_NAME `
    -Action   $action `
    -Trigger  $triggers `
    -Settings $settings `
    -RunLevel Limited `
    -Force | Out-Null

Write-Host "         Task registered — runs Mon-Fri at 09:00, 11:00, 14:00, 16:00."

# Step 4 — send install event to sheet
Write-Host "  [3/3] Registering install..."
$installBody = @{
    type       = "install"
    username   = $env:USERNAME
    source     = "install-revenue-editorial-windows"
    timestamp  = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    arch       = $env:PROCESSOR_ARCHITECTURE
    os         = [System.Environment]::OSVersion.VersionString
    department = $DEPARTMENT
} | ConvertTo-Json

try {
    Invoke-WebRequest -Uri $WEBHOOK_URL -Method Post `
        -ContentType "application/json" -Body $installBody -UseBasicParsing | Out-Null
} catch { }

Write-Host ""
Write-Host "  ✓ Installed for $DEPARTMENT / $SUBDEPT." -ForegroundColor Green
Write-Host "    The pulse will appear at scheduled times Mon-Fri."
Write-Host "    Launching now so you can test it..."
Write-Host ""

# Launch immediately for first test
powershell.exe -WindowStyle Normal -ExecutionPolicy Bypass -File "$PULSE_SCRIPT" -Test
