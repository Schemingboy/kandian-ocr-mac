# 看典古籍 OCR · Mac 客户端

复刻 Windows 版「看典古籍OCR客户端 v2.0.7」流程，让 Mac 也能用同一个账号做古籍 OCR：本地把 PDF 逐页转图 → 调云端 `ocr.kandianguji.com/ocr_api` → 逐页出 txt + 汇总。

## 功能

- **PDF 识别**：逐页 OCR，进度条 + 断点续跑；不同路径的同名 PDF、同一路径后来替换的 PDF 自动隔离，输出每页 txt、汇总.txt、汇总.docx
- **单图识别**：选一张古籍图直接识别，可复制
- **额度查询**：看 token 剩余额度与状态

## 官网与账号

- **官网**：<https://www.kandianguji.com>（古籍数字化、善本大全、全文检索、古籍校对）
- **注册 / 登录**：手机号 + 验证码，或微信登录；网页版、客户端、小程序共用同一账号与额度
- **获取 API Token**：登录官网 → 古籍数字化 → OCR API → 我的 API Token（新申请需人工审核，约 2 小时内通过）
- **额度**：OCR API 页面可付费充值（约 0.015 元/次），或扫码看广告加当日额度
- **网页版备用**：不方便装客户端时，浏览器打开官网「古籍数字化」页也能在线识别（PDF / 图片），流程和本客户端一致

## 安装（一次性，约 3 分钟）

要求：macOS 13 或更高版本、Python 3.10-3.14（低于 3.15）。已有 `.venv` 版本或架构与当前 `python3` 不一致时，安装脚本会在下载依赖前明确提示删除并重建。Apple Silicon 上用 Rosetta 运行 x86_64 Python 时，配套的 x86_64 `.venv` 可以正常沿用。

1. 装 Python：<https://www.python.org/downloads/>
2. 拿代码并安装：

   ```bash
   git clone https://github.com/Schemingboy/kandian-ocr-mac.git
   cd kandian-ocr-mac
   chmod +x install.sh run.command && ./install.sh
   ```

3. 启动：双击 `run.command` → 「设置」页填邮箱/手机号 + API Token → 「检查额度」→ PDF 识别

### 🤖 AI 一键安装（不用手敲命令）

在装了 Claude Code / Codex 的 Mac 上打开本仓库，把下面这段直接发给 AI 助手：

> 帮我一键安装这个仓库的「看典古籍 OCR」客户端：
> 1. 检查 macOS 是否为 13 或更高版本、python3 是否为 3.10-3.14，不满足就告诉我怎么处理
> 2. 若当前不在仓库目录，先 `git clone https://github.com/Schemingboy/kandian-ocr-mac.git` 并进入
> 3. 执行 `chmod +x install.sh run.command && ./install.sh`
> 4. 装完跑 `.venv/bin/python -c "import docx, fitz, requests; import PySide6; print('deps OK')"` 确认依赖
> 5. 完成后告诉我怎么启动，并引导我填 token

## 常见问题

| 问题 | 处理 |
|---|---|
| token无效 | 回官网「古籍数字化 → OCR API」重新复制 |
| 额度不足 | 官网 OCR API 页面充值 / 看广告加当日额度 |
| 个别页失败 | 正常，重跑勾「跳过已有结果」只补失败页 |
| 升级前已有 `PDF名/page_*.txt` | 旧目录会原样保留，新版不会自动继承，避免误用同名但来源不同的结果；需要续跑时请继续使用旧版，或人工确认后手动处理 |
| 再次启动应用 | 同一时间只允许启动一个实例；第二次启动会提示已有实例正在运行 |
| 主动停止 | 已完成页会保留，下次勾「跳过已有结果」即可续跑；本次取消不会更新汇总，既有汇总保持不变 |
| 关闭时仍在识别/查额度 | 窗口会显示“正在安全退出”，等待当前网络请求结束后自动关闭；单次 OCR 网络超时设置为 120 秒 |
| 竖排识别乱序 | 参数里「排版」选竖排 |

## 安全

- token 只存本机 `~/.kandian_ocr.json`（已 .gitignore），只发往看典官方接口
- 来源编号使用规范路径、文件大小、纳秒修改时间及首/中/尾各最多 64 KiB 抽样，每次最多读取 192 KiB，不会预读整份 PDF。它用于防止正常的同名/替换文件误续跑，不是完整内容校验；若有人刻意保持全部这些字段与抽样内容相同，理论上仍可能得到同一编号
- 识别结果仅供参考，关键内容人工核对

## 文件

`kandian_ocr.py` 主程序 · `install.sh` 安装 · `run.command` 启动 · `tests/` 自动检查
