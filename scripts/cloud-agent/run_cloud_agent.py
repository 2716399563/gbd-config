#!/usr/bin/env python3
"""从命令行驱动 Cursor Cloud Agent，并挂上服务器的 MCP。

用法:
    set CURSOR_API_KEY=cursor_xxx
    set MCP_KEY=mcp-ext-xxx
    python run_cloud_agent.py "列出 /workspace 目录并总结这个项目"

退出码:
    0  跑完且成功
    1  没启动起来（认证/配置/网络）
    2  启动了但执行失败
"""
from __future__ import annotations

import argparse
import os
import sys

from cursor_sdk import (
    Agent,
    AgentOptions,
    CloudAgentOptions,
    CloudRepository,
    CursorAgentError,
    HttpMcpServerConfig,
)

DEFAULT_REPO = "https://github.com/2716399563/gbd-config"
DEFAULT_REF = "main"
DEFAULT_MODEL = "composer-2.5"
MCP_URL = "https://20-255-73-137.sslip.io/mcp"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Run a Cursor Cloud Agent")
    p.add_argument("prompt", help="要让 Cloud Agent 做的事")
    p.add_argument("--repo", default=DEFAULT_REPO)
    p.add_argument("--ref", default=DEFAULT_REF, help="起始分支")
    p.add_argument("--model", default=DEFAULT_MODEL)
    p.add_argument("--name", default=None, help="Agent 名称（在 cursor.com/agents 里显示）")
    p.add_argument("--pr", action="store_true", help="跑完自动开 PR")
    p.add_argument("--no-mcp", action="store_true", help="不挂载 server-files MCP")
    return p.parse_args()


def build_options(args: argparse.Namespace) -> AgentOptions:
    api_key = os.environ.get("CURSOR_API_KEY", "").strip()
    if not api_key:
        sys.exit(
            "缺少 CURSOR_API_KEY。\n"
            "到 https://cursor.com/dashboard/integrations 生成后设置环境变量：\n"
            '    set CURSOR_API_KEY=cursor_xxx'
        )

    mcp_servers = None
    if not args.no_mcp:
        mcp_key = os.environ.get("MCP_KEY", "").strip()
        if mcp_key:
            # headers 由 Cursor 后端处理，不会下发到云端 VM
            mcp_servers = {
                "server-files": HttpMcpServerConfig(
                    url=MCP_URL,
                    type="http",
                    headers={"Authorization": f"Bearer {mcp_key}"},
                )
            }
        else:
            print("[warn] 未设置 MCP_KEY，本次不挂载 server-files", file=sys.stderr)

    return AgentOptions(
        api_key=api_key,
        model=args.model,
        name=args.name,
        # 必须显式给 cloud，否则 SDK 会静默跑成本地 agent
        cloud=CloudAgentOptions(
            repos=[CloudRepository(url=args.repo, starting_ref=args.ref)],
            auto_create_pr=args.pr,
            skip_reviewer_request=True,
        ),
        mcp_servers=mcp_servers,
    )


def stream(run) -> None:
    """尽力流式打印助手文本；SDK 消息结构变动时不要因此中断整个任务。"""
    try:
        for message in run.messages():
            if getattr(message, "type", None) != "assistant":
                continue
            for block in getattr(message.message, "content", []):
                if getattr(block, "type", None) == "text":
                    print(block.text, end="", flush=True)
        print()
    except Exception as exc:  # noqa: BLE001
        print(f"\n[warn] 流式输出中断（不影响任务）: {exc}", file=sys.stderr)


def main() -> int:
    args = parse_args()
    options = build_options(args)

    try:
        with Agent.create(options) as agent:
            run = agent.send(args.prompt)
            # 先记 ID：万一流式卡住，靠这两个 ID 去 dashboard 追
            print(f"agent_id={agent.agent_id}  run_id={run.id}", file=sys.stderr)
            print(f"跟踪: https://cursor.com/agents", file=sys.stderr)

            stream(run)
            result = run.wait()

            if result.status == "error":
                print(f"[error] 执行失败: {result.id}", file=sys.stderr)
                return 2
            print(f"[ok] status={result.status}", file=sys.stderr)
            return 0

    except CursorAgentError as exc:
        print(
            f"[fatal] 没能启动: {exc}  retryable={getattr(exc, 'is_retryable', '?')}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
