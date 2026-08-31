#!/usr/bin/env python3
"""Fail early when Codemagic receives an old or accidentally nested source tree."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path: str, text: str) -> None:
    target = ROOT / path
    if not target.is_file():
        raise SystemExit(f"MISSING AT REPOSITORY ROOT: {path}")
    if text not in target.read_text(encoding="utf-8"):
        raise SystemExit(f"OLD OR MIXED SOURCE: {path} is missing {text!r}")


require("project.yml", "MARKETING_VERSION: 0.7.3")
require("project.yml", "CURRENT_PROJECT_VERSION: 14")
require("ServerIDE/Info.plist", "RESUMABLE-DOWNLOAD-20260830-E")
require("ServerIDE/Views/RootView.swift", 'Label("Terminal"')
require("ServerIDE/Views/Workspace/SFTPView.swift", 'Section("Folders (')
require("ServerIDE/Views/Workspace/SFTPView.swift", 'Section("Files (')
require("ServerIDE/Views/Workspace/TerminalView.swift", 'control("Select freely"')
require("ServerIDE/Services/SSHConnectionManager.swift", "executeTerminal")
require("ServerIDE/Services/IPLookupService.swift", "Cloudflare trace")
require("ServerIDE/Views/Tools/ToolsView.swift", '"Network Discovery"')
require("ServerIDE/Views/Tools/ToolsView.swift", '"Certificate Checker"')
require("ServerIDE/Views/Tools/ToolsView.swift", '"Secret Share"')

if (ROOT / "ServerIDE" / "project.yml").exists():
    raise SystemExit("NESTED PROJECT: upload the package contents, not a ServerIDE wrapper folder")

print("PASS: repository root is ServerIDE 0.7.3 (14) / RESUMABLE-DOWNLOAD-20260830-E")
