# AGENTS.md — 给 AI 助手的安装与使用指南

目标：在这台 macOS 上装好「看典古籍 OCR」，并跑通一次 PDF 识别。
用户可能只说了「帮我装一下」，下面所有命令照顺序执行即可。

## 一键安装（依次执行）

```bash
# 1. 确认是 macOS 13+，且 Python 为 3.10-3.14；不满足时 install.sh 会在下载依赖前明确报错
sw_vers -productVersion
command -v python3 && python3 --version || echo "缺 Python 3.10-3.14，请先安装"

# 2. 已在仓库目录（有 .git）就跳过 clone；不在就 clone 到合适位置
[ -d .git ] || git clone https://github.com/Schemingboy/kandian-ocr-mac.git

# 3. 进入仓库目录后：加执行权限 + 装依赖（自动建 .venv，装 PySide6/requests/PyMuPDF/python-docx）
# 已有 .venv 只需与当前 python3 架构一致；Apple Silicon 的 Rosetta x86_64 Python/venv 组合允许使用
chmod +x install.sh run.command
./install.sh
```

## 装完自检（必须跑，别静默成功）

```bash
.venv/bin/python -c "import docx, fitz, requests; import PySide6; print('deps OK')"
[ -f kandian_ocr.py ] && echo "主程序存在"
```

## 启动

- GUI 需要真实显示器，agent 代点不了：让用户**双击 `run.command`**，或终端跑 `.venv/bin/python kandian_ocr.py`
- 若双击没反应：右键 → 打开（首次 macOS 会拦未签名脚本）；仍不行就终端直接跑看报错

## 修改后验证

```bash
.venv/bin/python -m unittest discover -s tests -v
bash tests/test_install_checks.sh
bash -n install.sh run.command tests/test_install_checks.sh
```

如当前机器还没安装 PySide6，可先用系统 Python 运行单元测试；测试会用最小 Qt 替身，不会读取或写入真实 Token。

## 首次配置（引导用户填，agent 绝不代填 token）

1. 「设置」页填：**邮箱/手机号**（注册看典用的那个）+ **API Token**（官网 → 古籍数字化 → OCR API）
2. 点「检查额度」，显示「已通过 · 可正常使用」即正常
3. 「PDF 识别」：选 PDF → 选保存文件夹 → 开始识别
4. 产物在保存文件夹下 `PDF名__来源编号/`：每页 `page_0001.txt`…、`汇总.txt`、`汇总.docx`。来源编号由路径、大小、修改时间和首/中/尾抽样共同确定：隔离不同路径的同名 PDF，也防止正常的同路径替换文件误续跑；不会全量读取大型 PDF。同一未变化 PDF 重跑仍进入同一目录。

## 故障排查

| 现象 | 处理 |
|---|---|
| pip 网络失败/慢 | 走代理后重跑 install.sh；或 `pip install -i https://pypi.tuna.tsinghua.edu.cn/simple "PySide6>=6.10,<7" requests PyMuPDF python-docx` |
| 提示 token无效 | 让用户回官网重新复制 token（勿从本机配置抄旧值） |
| OCR 个别页失败 | 正常现象，重跑时勾「跳过已有结果」只补失败页 |
| 发现旧版 `PDF名/page_*.txt` | 旧目录原样保留，新版不自动继承，避免误用同名但来源不同的结果；需要续跑时继续使用旧版，或人工确认后手动处理 |
| 再次启动应用 | 同一时间只允许启动一个实例；第二次启动会提示已有实例正在运行 |
| 主动停止 | 已完成页保留供续跑；本次取消不会更新汇总或显示为完整完成，既有汇总保持不变 |
| 竖排乱序 | 参数「排版」选竖排 |

## 红线

- **绝不读取、输出、写入用户的真实 API token / 账号**；token 只由用户在界面里填
- 不要修改 `kandian_ocr.py` 的核心识别逻辑，除非用户明确要求
