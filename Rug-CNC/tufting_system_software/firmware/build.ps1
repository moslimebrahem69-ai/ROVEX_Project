# سكريبت بديل لتجميع البرنامج بدون Make
# يتطلب GCC و PowerShell

param(
    [string]$Target = "all"
)

$CC = "gcc"
$CFLAGS = "-std=c11 -D_POSIX_C_SOURCE=200809L -D_DEFAULT_SOURCE -O2 -Wall -Wextra -Iinclude"
$LDFLAGS = "-lm"

$SRC_DIR = "src"
$BIN_DIR = "bin"
$TEST_DIR = "tests"

$CORE_SRCS = @(
    "$SRC_DIR/motion_profile.c",
    "$SRC_DIR/kinematics.c",
    "$SRC_DIR/path_loader.c",
    "$SRC_DIR/hal_sim.c",
    "$SRC_DIR/hal_serial.c"
)

$MAIN_SRC = "$SRC_DIR/main.c"

# إنشاء مجلد bin إذا لم يكن موجود
if (-not (Test-Path $BIN_DIR)) {
    New-Item -ItemType Directory -Path $BIN_DIR | Out-Null
    Write-Host "✓ تم إنشاء مجلد $BIN_DIR"
}

if ($Target -eq "all") {
    Write-Host "جاري بناء ROVEX..."
    $cmd = "$CC $CFLAGS -o $BIN_DIR/ROVEX.exe $MAIN_SRC $($CORE_SRCS -join ' ') $LDFLAGS"
    Write-Host $cmd
    Invoke-Expression $cmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ تم البناء بنجاح: $BIN_DIR/ROVEX.exe"
    }
    else {
        Write-Host "✗ خطأ في البناء"
        exit 1
    }
}
elseif ($Target -eq "test") {
    Write-Host "جاري بناء واختبار motion_profile..."
    $cmd = "$CC $CFLAGS -o $BIN_DIR/test_motion_profile.exe $TEST_DIR/test_motion_profile.c $SRC_DIR/motion_profile.c $LDFLAGS"
    Write-Host $cmd
    Invoke-Expression $cmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ تم البناء بنجاح، جاري تشغيل الاختبار..."
        & "$BIN_DIR/test_motion_profile.exe"
    }
    else {
        Write-Host "✗ خطأ في البناء"
        exit 1
    }
}
elseif ($Target -eq "clean") {
    if (Test-Path $BIN_DIR) {
        Remove-Item -Recurse -Force $BIN_DIR
        Write-Host "✓ تم حذف مجلد $BIN_DIR"
    }
}
else {
    Write-Host "استخدام: .\build.ps1 [all|test|clean]"
}
