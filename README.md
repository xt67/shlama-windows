# 🦙 shlama (Windows)

*Your terminal llama. Natural language → safe Windows commands. Powered by Ollama.*

> **🐧 Looking for Linux?** Check out [shlama for Linux](https://github.com/xt67/shlama-linux)

shlama is a CLI companion that turns natural language into shell commands using a local LLM (Ollama).  
You ask for something, it suggests a command, and **you approve before execution**.

No cloud. No API keys. Just your shell and a llama.

---

## ✨ Demo

```powershell
PS> shlama "list all files including hidden"
🦙 Thinking...

Suggested command:
Get-ChildItem -Force

Run command? (y/N): y

Executing...
─────────────────────────────────────
    Directory: C:\Users\You\Documents

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----          12/07/2025    10:00                Projects
-a---          12/07/2025    09:30           1234 notes.txt
─────────────────────────────────────
✓ Done
```

---

## 🚀 Installation

### One-Line Install (Recommended)

Open **PowerShell** and run:

```powershell
irm https://raw.githubusercontent.com/xt67/shlama-windows/main/install.ps1 | iex
```

This automatically installs:
- ✅ shlama
- ✅ Ollama (if not installed)
- ✅ Downloads the AI model of your choice

**Restart your terminal** after installation, then:
```powershell
shlama "list all files"
```

### Manual Installation

1. Install [Ollama for Windows](https://ollama.com/download)
2. Download `shlama.ps1` from this repo
3. Run: `ollama pull llama3.2`

---

## 📖 Usage

```powershell
shlama "<natural language request>"
```

### Examples

```powershell
# File operations
shlama "list all files including hidden"
shlama "find all python files"
shlama "show large files over 100MB"

# System info
shlama "show disk space"
shlama "show memory usage"
shlama "list running processes"

# Network
shlama "show my ip address"
shlama "ping google"
shlama "show network adapters"

# Package management (winget)
shlama "install vscode"
shlama "update all apps"
```

---

## ⚙️ Configuration

### Changing the AI Model

You can change the AI model at any time:

```powershell
shlama --model
```

This opens an interactive menu to select a different model.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SHLAMA_MODEL` | `llama3.2` | Ollama model to use (overrides saved config) |
| `OLLAMA_HOST` | `http://localhost:11434` | Ollama API endpoint |

### Examples

```powershell
# Use a different model temporarily
$env:SHLAMA_MODEL = "mistral"
shlama "list files"

# Set permanently
[Environment]::SetEnvironmentVariable("SHLAMA_MODEL", "llama3.2", "User")
```

---

## 🛡️ Safety

shlama is designed with safety in mind:

- ✅ **Confirmation required** - Every command needs your approval before execution
- ✅ **No auto-execute** - You always see the command first
- ✅ **Local only** - No data leaves your machine
- ✅ **Safe prompting** - The LLM is instructed to avoid destructive commands

> ⚠️ **Always review the suggested command before running it.** While shlama tries to generate safe commands, you are responsible for what runs on your system.

---

## 🤝 Contributing

Contributions are welcome! Feel free to:

- 🐛 Report bugs
- 💡 Suggest features
- 🔧 Submit pull requests

---

## 💖 Support

If you find shlama useful, consider supporting its development:

<a href="https://www.buymeacoffee.com/xt67" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="50" ></a>

<a href="https://onlychai.neocities.org/support.html?name=Rayyan%20Rahman&upi=onlystudies790-1%40oksbi" target="_blank"><img src="https://img.shields.io/badge/Buy_me_a_chai-🍵-FFDD00?style=for-the-badge&labelColor=FFDD00" alt="Buy Me A Chai"></a>

[![Sponsor on GitHub](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/xt67)

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 🔗 Related

- **[shlama for Linux](https://github.com/xt67/shlama-linux)** - The original Linux version
- [Ollama](https://ollama.com) - Local LLM runtime

---

<p align="center">
  Made with 🦙 by the terminal
</p>
