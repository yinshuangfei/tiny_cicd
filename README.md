# tiny_cicd

本地 CI：监控 `tiny_os` 仓库，发现 `push` 后拉取到 `build/`，在该目录编译并运行，打印测试结果。

默认监控仓库：`git@github.com:yinshuangfei/tiny_os.git`。

## 怎么用

先确认本机可以 SSH 访问 GitHub，并且已安装 `git`、`make`、`gcc`（x86 需要 `-m32`）、`qemu-system-x86_64`。跑 e2e 时还需要 `mkfs.ext2` 和 `debugfs`。

一次性拉取并执行 CI：

```bash
bash scripts/ci.sh
```

持续监控远程分支，有新提交就自动跑 CI：

```bash
bash scripts/watch.sh
```

只对已经拉下来的 `build/` 再编译运行，不再 fetch：

```bash
bash scripts/ci.sh --no-pull
```

## 流程

1. 用 `git ls-remote` 轮询远程 `main`（间隔见 `POLL_INTERVAL`）
2. 发现新的 commit 后，clone 或 `fetch` + `reset --hard` 到 `build/`
3. 在 `build/arch/x86` 编译 `kernel.elf`
4. 若仓库里有 `e2e_test/`，执行 `make e2e`；否则用 QEMU 做限时冒烟启动
5. 在终端打印编译/运行输出，并给出 PASS/FAIL 摘要
6. 完整日志写到 `logs/ci-<sha>.log`

首次启动 `watch.sh` 时，如果本地还没有记录过 commit，会先对当前远程 HEAD 跑一遍，然后等待下一次 push。

## 配置

`config.env`：

```bash
REPO_URL=git@github.com:yinshuangfei/tiny_os.git
BRANCH=main
ARCH=x86
POLL_INTERVAL=10
QEMU_TIMEOUT=25
```

也可以用环境变量覆盖，例如：

```bash
ARCH=riscv POLL_INTERVAL=5 bash scripts/watch.sh
```

`ARCH=x86` 编译 x86 内核并跑 e2e / QEMU。`ARCH=riscv` 编译 RISC-V 内核并用 `qemu-system-riscv64` 做冒烟启动。

## 目录

```text
.
|-- config.env              监控仓库、分支、架构
|-- README.md
|-- scripts/common.sh       公共配置
|-- scripts/ci.sh           拉取、编译、运行
|-- scripts/watch.sh        监控 push 并触发 CI
|-- build/                  tiny_os 工作副本（编译产物也在这里）
`-- logs/                   每次 CI 的完整日志
```

`build/` 是 git 忽略的工作区，不要手工往里面改代码；它始终与远程指定分支对齐。
