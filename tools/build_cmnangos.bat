@echo off
chcp 65001 >nul
setlocal

if "%~1"=="" (
  echo 사용법: build_cmnangos.bat "ClassicDB_1_12_1_z2815.sql.gz"
  echo 또는 .sql.gz 파일을 이 배치 파일 위에 드래그 앤 드롭하세요.
  pause
  exit /b 1
)

:: 출력 디렉터리 사전 생성
if not exist "%~dp0..\BestGearFinder" mkdir "%~dp0..\BestGearFinder"

:: 파이썬 스크립트 실행
python "%~dp0extract_cmnangos.py" "%~1" --output "%~dp0..\BestGearFinder\GearDatabase.lua"

if errorlevel 1 (
  echo.
  echo [오류] 스크립트 실행 중 에러가 발생했습니다.
  pause
  exit /b %errorlevel%
)

echo.
echo BestGearFinder GearDatabase.lua 생성 완료.
pause