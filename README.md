# 看典古籍 OCR · Mac 客户端

复刻 Windows 版「看典古籍OCR客户端 v2.0.7」流程，让 Mac 也能用同一个账号做古籍 OCR：本地把 PDF 逐页转图 → 调云端 `ocr.kandianguji.com/ocr_api` → 逐页出 txt + 汇总。

## 功能

- **PDF 识别**：逐页 OCR，进度条 + 断点续跑，输出每页 txt、汇总.txt、汇总.docx
- **单图识别**：选一张古籍图直接识别，可复制
- **额度查询**：看 token 剩余额度与状态

## 安装（一次性，约 3 分钟）

1. 装 Python：<https://www.python.org/downloads/>（勾选 Add to PATH）
2. 拿代码并安装：

   ```bash
   git clone https://github.com/Schemingboy/kandian-ocr-mac.git
   cd kandian-ocr-mac
   chmod +x install.sh run.command && ./install.sh
   ```

3. 启动：双击 `run.command` → 「设置」页填邮箱/手机号 + API Token → 「检查额度」→ PDF 识别

> **想用 AI 一键装？** 在装了 Claude Code / Codex 的 Mac 上打开本仓库，让 agent 读 `AGENTS.md` 照着执行即可，不用手敲命令。

## 常见问题

| 问题 | 处理 |
|---|---|
| token无效 | 回官网「古籍数字化 → OCR API」重新复制 |
| 额度不足 | 官网 OCR API 页面充值 / 看广告加当日额度 |
| 个别页失败 | 正常，重跑勾「跳过已有结果」只补失败页 |
| 竖排识别乱序 | 参数里「排版」选竖排 |

## 安全

- token 只存本机 `~/.kandian_ocr.json`（已 .gitignore），只发往看典官方接口
- 识别结果仅供参考，关键内容人工核对

## 文件

`kandian_ocr.py` 主程序 · `install.sh` 安装 · `run.command` 启动 · `AGENTS.md` AI 安装指南
