# Claude Code Bootstrap Agent

> Claude Code를 한 줄로 설치하는 크로스 플랫폼 셋업 에이전트

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS-blue.svg)](https://www.apple.com/macos/)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org/)

## Quick Start

다운로드한 폴더에서 아래 명령어를 실행하세요.

### macOS / Linux

```bash
./install.sh
```

### Windows (PowerShell 관리자 권한으로 실행)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-win.ps1
```

## Features

- **자동 환경 감지**: OS, 아키텍처, 기존 설치 여부 자동 확인
- **스마트 설치**: 필요한 것만 선별 설치
- **멱등성 보장**: 여러 번 실행해도 안전
- **친절한 UI**: 컬러풀한 진행 상황 표시
- **크로스 플랫폼**: macOS, Windows, Linux 지원

## What Gets Installed

| Component | macOS | Windows | Linux |
|-----------|:-----:|:-------:|:-----:|
| Homebrew | ✅ | - | - |
| winget | - | ✅ | - |
| Node.js 18+ | ✅ | ✅ | ✅ |
| npm | ✅ | ✅ | ✅ |
| Claude Code | ✅ | ✅ | ✅ |

## System Requirements

### macOS
- macOS 10.15 (Catalina) 이상
- Apple Silicon (M1/M2/M3) 또는 Intel 프로세서
- 터미널 앱 (zsh 또는 bash)

### Windows
- Windows 10 버전 1809 이상 또는 Windows 11
- PowerShell 5.1 이상
- winget (자동 설치됨)

### Linux
- Ubuntu 18.04+, Debian 10+, Fedora 32+, CentOS 8+, Arch Linux
- apt, dnf, yum, pacman, 또는 apk 패키지 매니저

## Installation Flow

```
┌─────────────────────────────────────────────────────────┐
│                    스크립트 실행                          │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              OS/환경 자동 감지                            │
│         (macOS/Windows/Linux, zsh/PowerShell)           │
└─────────────────────────────────────────────────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│     macOS        │ │     Windows      │ │     Linux        │
│  setup-mac.sh    │ │  setup-win.ps1   │ │  setup-mac.sh    │
└──────────────────┘ └──────────────────┘ └──────────────────┘
              │            │            │
              └────────────┼────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│                 설치 완료 & 검증                          │
│            `claude --version` 실행 확인                  │
└─────────────────────────────────────────────────────────┘
```

## Project Structure

```
cc-bootstrap/
├── README.md                 # 프로젝트 설명 및 사용법
├── LICENSE                   # MIT 라이선스
│
├── install.sh                # 통합 진입점 (curl로 실행)
│
├── scripts/
│   ├── setup-mac.sh          # macOS/Linux 전용 설치 스크립트
│   ├── setup-win.ps1         # Windows PowerShell 스크립트
│   └── common.sh             # 공통 유틸리티 함수
│
├── lib/
│   ├── detect.sh             # 환경 감지 함수
│   ├── install-node.sh       # Node.js 설치 로직
│   └── install-claude.sh     # Claude Code 설치 로직
│
└── tests/
    ├── test-mac.sh           # macOS/Linux 테스트
    └── test-win.ps1          # Windows 테스트
```

## Manual Installation

설치 스크립트 없이 수동 설치:

```bash
# 1. Node.js 18+ 설치
# https://nodejs.org 에서 다운로드하거나:

# macOS (Homebrew)
brew install node

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Windows (winget)
winget install OpenJS.NodeJS.LTS

# 2. Claude Code 설치
npm install -g @anthropic-ai/claude-code

# 3. 실행
claude
```

## Troubleshooting

### macOS: "command not found: brew"

Homebrew 설치 후 쉘을 재시작하거나:

```bash
# Apple Silicon
eval "$(/opt/homebrew/bin/brew shellenv)"

# Intel
eval "$(/usr/local/bin/brew shellenv)"
```

### Windows: "스크립트를 실행할 수 없습니다" / "디지털 서명되지 않았습니다"

PowerShell 실행 정책 때문입니다. 다음 명령어로 실행하세요:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-win.ps1
```

### Windows: "winget is not recognized"

Microsoft Store에서 'App Installer'를 설치하세요:
https://www.microsoft.com/store/productId/9NBLGGH4NNS1

### "claude: command not found"

터미널을 재시작하거나 PATH를 새로고침:

```bash
# macOS/Linux
source ~/.zshrc  # 또는 ~/.bashrc

# Windows (새 PowerShell 창 열기)
```

### Node.js 버전이 너무 낮음

스크립트가 자동으로 업그레이드를 시도합니다. 수동 업그레이드:

```bash
# macOS
brew upgrade node

# Windows
winget upgrade OpenJS.NodeJS.LTS
```

## Running Tests

### macOS/Linux
```bash
chmod +x tests/test-mac.sh
./tests/test-mac.sh
```

### Windows
```powershell
.\tests\test-win.ps1
```

## Security Considerations

- 스크립트는 HTTPS를 통해서만 다운로드됩니다
- 각 단계에서 설치 전 확인 메시지를 출력합니다
- 기존 설치를 덮어쓰지 않고 업데이트만 수행합니다
- 소스 코드는 공개되어 있어 검토 가능합니다

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Resources

- [Claude Code 공식 문서](https://docs.anthropic.com/claude-code)
- [Node.js 다운로드](https://nodejs.org)
- [Homebrew](https://brew.sh)
- [winget 문서](https://docs.microsoft.com/windows/package-manager/winget)

## License

MIT License - see the [LICENSE](LICENSE) file for details.

---

Made with by the Claude Code Bootstrap Team
